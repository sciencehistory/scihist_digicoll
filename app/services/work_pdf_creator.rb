require 'open-uri'

# Create a PDF where each image in a work is embedded as a JPG page, using the "download_large" derivative.
#
# Known limitation: If a work contains child works (rather than direct assets), only one single representative
# image for each child is included.
#
#     WorkPdfCreator.new(work).create_zip
#
# Will return a ruby Tempfile that is NOT closed/unliked, up to caller to take care
# of it.
##
# Callback is a proc that takes keyword arguments `progress_total` and `progress_i` to receive progress info
# for reporting to user.
#
# DEPENDS ON `pdfunite` command-line utility, which is installed with `poppler` which was a dependency
# for our vips use anyway.
class WorkPdfCreator
  PAGE_WIDTH = 612
  PAGE_HEIGHT = 792

  DERIVATIVE_SOURCE = "download_large"

  # for memory consumption, we first make PDFs of at most BATCH_SIZE pages, then
  # combine them.
  BATCH_SIZE = 50

  attr_reader :work, :callback

  # @param work [Work] Work object, it's members will be put into a zip
  # @param callback [proc], proc taking keyword arguments progress_i: and progress_total:, can
  #   be used to update a progress UI.
  def initialize(work, callback: nil)
    @work = work
    @callback = callback
  end

  # Returns a Tempfile. Up to caller to close/unlink tempfile when done with it.
  def create
    tempfile = tmp_pdf_file!
    write_pdf_to_path(tempfile.path)
    return tempfile
  end

  private

  def total_page_count
    @total_page_count ||= members_to_include.count
  end

  # published members. pre-loads leaf_representative derivatives.
  # Limited to members whose leaf representative has a download_large derivative
  #
  # Members will have derivatives pre-loaded.
  def members_to_include
    @members_to_include ||= work.
                            members.
                            includes(:leaf_representative).
                            where(published: true).
                            order(:position).
                            select do |m|
                              m.leaf_representative&.file_derivatives(DERIVATIVE_SOURCE.to_sym)
                            end
  end

  def tmp_pdf_file!
    Tempfile.new(["pdf-#{work.friendlier_id}", ".pdf"]).tap { |t| t.binmode }
  end

  # We're going to make a PDF with prawn of up to 50 pages at a time -- to save memory, since prawn
  # uses more memory making larger PDFs. Then we will join them all with commandline call-out to
  # pdfunite (a command-line tool that comes with `poppler`), to the location specified.
  #
  # And we'll make sure to clean up any temporary files.
  def write_pdf_to_path(output_filepath)
    Dir.mktmpdir("scihist_digicoll_#{self.class.name}") do |working_directory|
      chunk_filepaths = []

      chunk_index = 0
      members_to_include.each_slice(BATCH_SIZE) do |members_chunk|
        chunk_path = File.join(working_directory, "pdf_chunk#{chunk_index}.pdf")
        chunk_filepaths << chunk_path

        make_prawn_pdf(source_members: members_chunk, index_start_offset: chunk_index * BATCH_SIZE).render_file(chunk_path)

        chunk_index += 1
      end

      # Now we gotta combine all our separate PDF files into one big one, which pdfunite
      # can do 'relatively' quickly and memory-efficiently. It also preserves PDF Info Dictionary from first PDF.
      TTY::Command.new(printer: :null).run("pdfunite", *chunk_filepaths, output_filepath)
    end
  end


  # you probably want {#write_pdf} instead. We intentionally write to disk
  # to not use huge RAM for our potentially huge PDFs.
  #
  # @returns [Prawn::Document]
  def make_prawn_pdf(source_members:, index_start_offset: 0)
    pdf = Prawn::Document.new(
      margin: 0,
      skip_page_creation: true,
      page_size: [PAGE_WIDTH, PAGE_HEIGHT],
      layout: "portrait",
      # PDF metadata woot
      info: {
        Title: work.title,
        Creator: "Science History Institute",
        Producer: "Science History Institute",
        CreationDate: Time.now,
        # for lack of a better PDF tag...
        Subject: "#{ScihistDigicoll::Env.lookup!(:app_url_base)}/works/#{work.friendlier_id}",
        # not a standard PDF tag, but we'll throw it in
        Url: "#{ScihistDigicoll::Env.lookup!(:app_url_base)}/works/#{work.friendlier_id}"
      }
    )

    tmp_files = []

    source_members.each_with_index do |member, index|
      embed_width, embed_height = image_embed_dimensions(member.leaf_representative)
      # If they were missing, we do our best
      embed_width ||= PAGE_WIDTH
      embed_height ||= PAGE_HEIGHT

      pdf.start_new_page(size: [embed_width, embed_height], margin: 0)

      # unfortunately making a temporary local file on disk in order to add it to PDF
      tmp_file = member.leaf_representative.file_derivatives(DERIVATIVE_SOURCE.to_sym).open
      tmp_files << tmp_file

      pdf.image tmp_file, vposition: :center, position: :center, fit: [embed_width, embed_height]

      # We don't really need to update on every page, the front-end is only polling every two seconds anyway
      if callback && (index % 3 == 0 || index >= total_page_count - 1)
        callback.call(progress_total: total_page_count, progress_i: index_start_offset + index + 1)
      end
    end

    return pdf
  ensure
    (tmp_files || []).each do |tmp_file|
      # close should be enough to clean up whatever is returned from Shrine #open --
      # if we switch to using shrine #download we might need to reexamine!
      tmp_file.close
    end
  end

  # We want to fit the image on an 8.5x11 page, expressed in prawn's 72 dpi coordinates.
  # At the moment, instead of actually marking a page as 'landscape' orientation (which would
  # require rotating the image), we'll allow the page to be EITHER 8.5x11 or 11x8.5. This might
  # cause weirdness if someone wants to print, we may improve later -- but MacOS Preview
  # at least rotates the page for you when printing (whether you like it or not, in default settings).
  #
  # So chooses sizes such that original aspect ratio is maintained, and both dimensions fit into
  # either 8.5x11 or 11x8.5, expressed with 72dpi coordinates.
  #
  # Returns an array tuple `[w, h]`
  def image_embed_dimensions(asset)
    unless asset.width.present? && asset.height.present?
      # shouldn't happen, and we can do nothing.
      Rails.logger.error("#{self.class.name}: Couldn't find height and width to make PDF for #{work.friendlier_id}")
      return nil
    end

    target_aspect_ratio = PAGE_WIDTH.to_f / PAGE_HEIGHT.to_f
    target_aspect_ratio_sideways = PAGE_HEIGHT.to_f / PAGE_WIDTH.to_f

    source_aspect_ratio = asset.width.to_f / asset.height.to_f

    if source_aspect_ratio < target_aspect_ratio
      embed_height = PAGE_HEIGHT
      embed_width = (PAGE_HEIGHT.to_f * source_aspect_ratio).round
    elsif source_aspect_ratio < target_aspect_ratio_sideways
      embed_width = PAGE_WIDTH
      embed_height = (PAGE_WIDTH.to_f / source_aspect_ratio).round
    else
      embed_width = PAGE_HEIGHT
      embed_height = (PAGE_HEIGHT.to_f / source_aspect_ratio).round
    end

    return [embed_width, embed_height]
  end
end
