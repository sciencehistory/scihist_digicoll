# Takes a born digital PDF, and can extract page images and text (in hocr),
# to create local Assets representing each page as an image with text.
#
# Requires command lines:
#  * vips
#  * pdftotext (from poppler-utils)
#
# Call #cleanup after you are done to clean up internal tmp files please!
class PdfToPageImages
  DEFAULT_TARGET_DPI = 300

  class_attribute :vips_command, default: "vips"
  class_attribute :pdftotext_command, default: "pdftotext"

  attr_reader :pdf_file_path, :dpi

  # @param pdf_asset [Asset] asset holding a pdf
  # @param dpi [Integer] dpi we are extracting page image at, defaults to 300
  def initialize(pdf_file_path, dpi: DEFAULT_TARGET_DPI)
    @pdf_file_path = pdf_file_path
    @dpi = dpi
  end

  # @param page_num 1-BASED page number of PDF
  # @return [TmpFile] pointing to a JPEG
  def extract_jpeg_for_page(page_num)
    tempfile = Tempfile.new(["tmp_#{self.class.name}_", ".jpg"])

    TTY::Command.new(printer: :null).run(
      vips_command,
      "copy",
      # this tool uses 0-based page numbers
      "#{pdf_file_path}[page=#{page_num - 1},dpi=#{dpi}]",
      tempfile.path
    )

    return tempfile
  rescue StandardError => e
    tempfile.unlink if tempfile
    raise e
  end

  def cleanup
    @pdf_file&.unlink
  end

  protected

  def pdf_file
    @pdf_file ||= @pdf_asset.file.download
  end

end
