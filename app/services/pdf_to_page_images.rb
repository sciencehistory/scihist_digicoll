# Takes a born digital PDF, and can extract page images and text (in hocr),
# to create local Assets representing each page as an image with text.
#
# Requires command lines:
#  * vips
#  * pdftotext (from poppler-utils)
#
# Since we take a pdf file on disk as an argument, you must deal with getting that local pdf file.
# Here's the most likely way you'll do that:
#
#     asset = Asset.find # something, get asset with original PDF
#     asset.file.download do |pdf_file_tmp|
#        # do as many operations in here as you want with a single PDF download,
#        # that will be cleaned up for you after block ends
#
#        service = PdfToPageImages.new(pdf_file_temp)
#        service.create_asset_for_page(1, source_pdf_sha512: asset.sha512, source_pdf_asset_pk: asset.id)
#     end
#
class PdfToPageImages
  DEFAULT_TARGET_DPI = 300
  EXTRACTED_PAGE_ROLE = "extracted_pdf_page"

  class_attribute :vips_command, default: "vips"
  class_attribute :pdftotext_command, default: "pdftotext"

  attr_reader :pdf_file_path, :dpi

  # @param pdf_asset [Asset] asset holding a pdf
  # @param dpi [Integer] dpi we are extracting page image at, defaults to 300. We need to make sure we target
  #   consistent DPI in image and hocr, so they match!
  def initialize(pdf_file_path, dpi: DEFAULT_TARGET_DPI)
    @pdf_file_path = pdf_file_path
    @dpi = dpi
  end

  # Create multiple page extract Assets. Either for every page, or for a range between from and to pages inclusive
  def create_assets_for_pages(work:, from:1, to:num_pdf_pages, on_existing_dup: :insert_dup,
                              source_pdf_sha512:, source_pdf_asset_pk:)
    (from..to).each do |page_num|
      create_asset_for_page(page_num, work: work,
          on_existing_dup: on_existing_dup,
          source_pdf_sha512: source_pdf_sha512,
          source_pdf_asset_pk: source_pdf_asset_pk)
    end

    nil
  end

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
  # @param on_existing_dup [Symbol] Check for existing Asset representing this page_num?
  #    * :insert_dup : Don't check, just go ahead and cretae a new one regardless
  #    * :abort : If one already exists, do nothing else but return it. Can be used to lazily create.
  #    * :overwrite : If one already exists, overwrite it's data with our data, keeping the record and it's friendlier_id
  #
  # @param source_pdf_sha512 [string] for tracking purposes, pass in nil if you really don't want
  # @param source_pdf_asset_pk [string] for tracking purposes, pass in nil if you really don't want
  #
  # @returns [Asset] persisted to db and fully shrine-promoted
  def create_asset_for_page(page_num,
                            work:,
                            on_existing_dup: :insert_dup,
                            source_pdf_sha512:,
                            source_pdf_asset_pk:)
    page_num_arg_check!(page_num)

    unless on_existing_dup == :insert_dup
      # going to go to DB once per Asset, even if we're loading multiple, sorry,
      # too complex to optimize when our main use case is likely to be one at a time
      existing_asset = Asset.jsonb_contains("extracted_pdf_source_info.page_index" => page_num).where(parent_id: work.id).first

      if existing_asset && on_existing_dup == :abort
        return existing_asset
      elsif existing_asset && on_existing_dup == :overwrite
        asset = existing_asset
      end
    end

    image = extract_jpeg_for_page(page_num)
    hocr = extract_hocr_for_page(page_num)

    # We might already have one from an existing asset to overwrite, in which
    # case we overwrite attributes but keep friendlier_id intact! Otherwise,
    # create a new one.
    #
    # Ideally we'd skip the shrine cache phase entirely, but it's too hard
    # to at present. We do do promotion and derivatives inline
    asset ||= Asset.new(parent: work)
    asset.assign_attributes(hocr: hocr,
                            file: image,
                            position: page_num,
                            extracted_pdf_source_info: {
                              page_index: page_num,
                              source_pdf_sha512: source_pdf_sha512,
                              source_pdf_asset_pk: source_pdf_asset_pk
                            },
                            role: EXTRACTED_PAGE_ROLE,
                            # right-pad page with zeroes so sorts alphabetically if we do so in admin UI!
                            title: "#{"%04d" % page_num} page extracted from #{work.friendlier_id}"
    )
    asset.set_promotion_directives(promote: :inline, create_derivatives: :inline)
    asset.save!

    asset
  ensure
    #tempfile
    if image
      image.close
      image.unlink
    end
  end

  # @param page_num 1-BASED page number of PDF
  # @return [TempFile] pointing to a JPEG
  def extract_jpeg_for_page(page_num)
    page_num_arg_check!(page_num)

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
    page_num_arg_check!(page_num)

    args = [
      pdftotext_command,
      "-bbox-layout",
      pdf_file_path,
      # this tool uses 1-based page numbers
      "-f", page_num,
      "-l", page_num,
      "-" # stdout output
    ]

    poppler_bbox_layout_out, err = TTY::Command.new(printer: :null).run( *args)


    # if there are no actual words, this still gives us HTML skeleton back, but with
    # nothing in it... just return nil, don't return an empty hocr
    unless poppler_bbox_layout_out.include?("<word")
      return nil
    end

    meta_tags = {
      "pdftotext-command" => args.join(" "),
      "pdftotext-version" => `#{pdftotext_command} -v 2>&1`,
      "pdftotext-conversion" => "converted from pdftotext to hocr by ScihistDigicoll app PopplerBboxToHocr class",
      "pdftotext-generation-date" => DateTime.now.iso8601
    }

    return PopplerBboxToHocr.new(poppler_bbox_layout_out, dpi: dpi, meta_tags: meta_tags).transformed_to_hocr
  end

  def num_pdf_pages
    @num_pdf_pages ||= PDF::Reader.new(pdf_file_path).page_count
  end

  def page_num_arg_check!(arg)
    unless arg > 0 && arg <= num_pdf_pages
      raise ArgumentError.new("page_num arg '#{arg}' must be between 1 and #{num_pdf_pages}")
    end
  end
end
