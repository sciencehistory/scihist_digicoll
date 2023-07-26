# Create a PDF where each image in a work is embedded as an image, possibly with OCR text layer, if OCR
# text is available.
#
# Known limitation:
#
#  * If a work contains child works (rather than direct assets), only one single representative
#    image for each child is included.
#
#         WorkPdfCreator.new(work).create_zip
#
#  * We create individual page PDFs, then combine them. If the individual page PDFs were created with
#    a tesseract textonly_layer, then EACH ONE has an embedded "glyphless font" from tesseract,
#    and these are DUPLICATED in the combined PDF. I think these should be pretty tiny though,
#    maybe adding only 5K?  https://github.com/tesseract-ocr/tesseract/blob/54b9fe4de9f0aa3af15f52a6f27ffaf758b43769/src/api/pdf_ttf.h
#    5K per page should add maybe 1.5% to total PDF size, not ideal, but so goes it.
#
# Will return a ruby Tempfile that is NOT closed/unliked, up to caller to take care
# of it.
##
# Callback is a proc that takes keyword arguments `progress_total` and `progress_i` to receive progress info
# for reporting to user.
#
# DEPENDS ON `pdfunite` command-line utility, which is installed with `poppler` which was a dependency
# for our vips use anyway.
class WorkPdfCreator2
  class PdfCreationFailure < RuntimeError ; end

  class_attribute :qpdf_command, default: "qpdf"

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
  rescue StandardError => e
    # if we raised, clean up the tempfile first
    if tempfile
      tempfile.close
      tempfile.unlink
    end

    # re-raise
    raise e
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
                            order(:position)
  end

  def tmp_pdf_file!
    Tempfile.new(["pdf-#{work.friendlier_id}", ".pdf"]).tap { |t| t.binmode }
  end

  # Make PDF pages of all
  def write_pdf_to_path(output_filepath)
    Dir.mktmpdir("scihist_digicoll_#{self.class.name}") do |working_directory|
      file_names = []

      # We can't do "find_each", cause we DO need the order, to order
      # page numbers. So we'll fetch all pages at once, that's fine.
      members_to_include.each_with_index do |member, page_index|
        file_name = "pdf_page#{'%05d' % page_index}.pdf"
        file_path = File.join(working_directory, file_name)

        temp_pdf_file = AssetPdfCreator.new(member.leaf_representative).create

        # mv to where we want for assembly!
        FileUtils.mv(temp_pdf_file.path, file_path)
        file_names << file_path

        # We don't really need to update on every page, the front-end is only polling every two seconds anyway
        if callback && (page_index % 3 == 0 || (page_index + 1)  >= total_page_count)
          callback.call(progress_total: total_page_count, progress_i: page_index + 1)
        end
      end

      if file_names.empty?
        raise PdfCreationFailure, "#{self.class.name}: No PDF files to join; are there no suitable images in work? work: #{work.friendlier_id}; total_page_count: #{total_page_count}"
      end

      concatenate_pdfs(file_names, output_path: output_filepath )
    end
  end

  def concatenate_pdfs(input_pdf_paths, output_path:)
      # Now we gotta combine all our separate PDF files into one big one, which pdfunite
      # can do 'relatively' quickly and memory-efficiently. It also preserves PDF Info Dictionary from first PDF.
      TTY::Command.new(printer: :null).run(
        qpdf_command,
        "--linearize", # better PDF for streaming/download
        "--empty", # start with empty pdf
        "--pages", *input_pdf_paths,
        "--",
        output_path
      )
  end
end
