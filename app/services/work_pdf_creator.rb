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
class WorkPdfCreator
  PAGE_WIDTH = 612
  PAGE_HEIGHT = 792

  DERIVATIVE_SOURCE = "download_large"

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

  # published members. pre-loads leaf_representative derivatives.
  # Limited to members whose leaf representative has a download_large derivative
  #
  # Members will have derivatives pre-loaded.
  def members_to_include
    @members_to_include ||= work.
                            members.
                            with_representative_derivatives.
                            where(published: true).
                            order(:position).
                            select do |m|
                              deriv = m.leaf_representative&.derivative_for(DERIVATIVE_SOURCE)
                              deriv && deriv.file.present?
                            end
  end

  def tmp_pdf_file!
    Tempfile.new(["pdf-#{work.friendlier_id}", ".pdf"]).tap { |t| t.binmode }
  end

  def write_pdf_to_path(filepath)
    make_prawn_pdf.render_file(filepath)
  end

  def write_pdf_to_stream(io, callback: nil)
    io.write make_prawn_pdf.render
  end

  # you probably want {#write_pdf} instead. We intentionally write to disk
  # to not use huge RAM for our potentially huge PDFs.
  #
  # @returns [Prawn::Document]
  def make_prawn_pdf
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

    count = members_to_include.count

    tmp_files = []

    members_to_include.each_with_index do |member, index|
      embed_width, embed_height = image_embed_dimensions(member.leaf_representative)
      # If they were missing, we do our best
      embed_width ||= PAGE_WIDTH
      embed_height ||= PAGE_HEIGHT

      pdf.start_new_page(size: [embed_width, embed_height], margin: 0)

      # unfortunately making a temporary local file on disk in order to add it to jpg
      tmp_file = member.leaf_representative.derivative_for(DERIVATIVE_SOURCE).file.open
      tmp_files << tmp_file

      pdf.image tmp_file, vposition: :center, position: :center, fit: [embed_width, embed_height]

      # We don't really need to update on every page, the front-end is only polling every two seconds anyway
      if callback && (index % 3 == 0 || index == count - 1)
        callback.call(progress_total: count, progress_i: index + 1)
      end
    end

    return pdf
  ensure
    (tmp_files || []).each do |tmp_file|
      # don't entirely understand what shrine is giving us when
      tmp_file.close
      if tmp_file.respond_to?(:unlink)
        tmp_file.unlink
      else
        File.unlink(tmp_file.path)
      end
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
