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
  EXTRACTED_PAGE_ROLE = "extracted_pdf_page"

  class_attribute :vips_command, default: "vips"
  class_attribute :pdftotext_command, default: "pdftotext"

  attr_reader :pdf_file_path, :dpi

  # @param pdf_asset [Asset] asset holding a pdf
  # @param dpi [Integer] dpi we are extracting page image at, defaults to 300
  def initialize(pdf_file_path, dpi: DEFAULT_TARGET_DPI)
    @pdf_file_path = pdf_file_path
    @dpi = dpi
  end

  # TODO: Check for already existing, with force overwrite? create and set roles.
  #
  # Creates an Asset with individual page extracted from PDF, including jpg and hocr,
  # and the usual shrine derivatives etc.
  #
  # All work is done in foreground and can be slow!
  #
  # May enqueue a fixity checking bg job, which we don't really care about, but that's how
  # we treat assets, so it's there.
  #
  # @param page_num 1-based page number of PDF
  # @param work [Work] set parent work so we can set some metadata and parent
  #
  # @returns [Asset] persisted to db and fully shrine-promoted
  def create_asset_for_page(page_num, work:)
    image = extract_jpeg_for_page(page_num)
    hocr = extract_hocr_for_page(page_num)

    # Ideally we'd skip the shrine cache phase entirely, but it's too hard
    # to at present. We do do promotion and derivatives inline
    asset = Asset.new(hocr: hocr, file: image, position: page_num,
                      role: EXTRACTED_PAGE_ROLE,
                      parent: work, title: "page #{page_num} extracted from #{work.friendlier_id}")
    asset.set_promotion_directives(promote: :inline, create_derivatives: :inline)
    asset.save!

    asset
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

  # @param page_num 1-BASED page number of PDF
  # @return [String] containing HOCR, or nil if no text in PDF page
  def extract_hocr_for_page(page_num)
    poppler_bbox_layout_out, err = TTY::Command.new(printer: :null).run(
      pdftotext_command,
      "-bbox-layout",
      pdf_file_path,
      # this tool uses 1-based page numbers
      "-f", page_num,
      "-l", page_num,
      "-" # stdout output
    )

    # if there are no actual words, this still gives us HTML skeleton back, but with
    # nothing in it... just return nil, don't return an empty hocr
    unless poppler_bbox_layout_out.include?("<word")
      return nil
    end

    return PopplerBboxToHocr.new(poppler_bbox_layout_out).transformed_to_hocr
  end
end
