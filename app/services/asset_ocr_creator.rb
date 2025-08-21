# For a specific asset, run image through OCR with tesseract, to get:
#
#   * HOCR output, attach to asset at Asset#hocr
#   * a textonly_pdf from tesseract (PDF with invisible text only and nothing else),
#     attached to asset as a derivative `textonly_pdf`
#
# Will overwrite any existing such things on asset, will run whether or not there is existing.
#
# * We run on the full-res TIFF, although this is slower, it will give us best results.
#
# * While some versions of tesseract are supposed to be able to read directly from URI,
#   the 4.1.1 we currently have on heroku cannot, so we have to download temp copy,
#   which does make this even slower. (Wait, should we pipe curl to it instead?)
#
class AssetOcrCreator
  # number_to_human for logging
  include ActionView::Helpers::NumberHelper

  BASE_OUT_FILENAME = "tesseract_out"

  # Based on environment it runs in, current value based on running jobs
  # in heroku standard-1x, how much before too much RAM?
  # https://github.com/sciencehistory/scihist_digicoll/issues/2825
  MAX_INPUT_FILE_SIZE = 210.megabytes

  # dropping width/dpi by 2 is essentially a FOUR-fold reduction in size, although
  # in fact we're seeing a lot MORE than that? Not sure why, should be enough though.
  # We think even factors of two is better for downsample quality? not sure.
  DEFAULT_DOWNSAMPLE_RATIO = 0.5

  TYPE_TO_SUFFIX = Rack::Mime::MIME_TYPES.invert

  class_attribute :tesseract_executable, default: "tesseract"
  class_attribute :vips_executable, default: "vips"

  # key is language in our metadata language field, value
  # is language as tesseract labels it. For languages we
  # currently handle.
  TESS_LANGS = {
    "English" => "eng",
    "German"  => "deu",
    "French"  => "fra",
    "Spanish" => "spa"
  }.freeze

  attr_reader :asset, :force_downsample, :downsample_ratio

  def self.suitable_language?(work)
    ((work.language || []) &  TESS_LANGS.keys).present?
  end


  def initialize(asset, force_ocr_over_extracted_page: false, force_downsample: false, downsample_ratio: DEFAULT_DOWNSAMPLE_RATIO)
    unless asset&.content_type&.start_with?("image/")
      raise ArgumentError, "Can only use with content type begining `image/`, not #{asset.content_type}"
    end

    if asset.role == PdfToPageImages::EXTRACTED_PAGE_ROLE && !force_ocr_over_extracted_page
      raise TypeError.new("We refuse to OCR on a PDF with role #{PdfToPageImages::EXTRACTED_PAGE_ROLE} because you probably don't want this?")
    end

    @asset = asset
    @force_downsample = !!force_downsample
    @downsample_ratio = DEFAULT_DOWNSAMPLE_RATIO
  end

  def call
    should_downsample = force_downsample || asset.file_metadata["size"] > MAX_INPUT_FILE_SIZE
    hocr_file, textonly_pdf_file = get_hocr(downsample: should_downsample)

    # read hocr file into string to set as json attribute
    asset.hocr = hocr_file.read

    # save admin note if downsampled
    if should_downsample
      asset.admin_note << "#{I18n.localize Time.current}: OCR done on original downsampled by #{downsample_ratio}"
    end

    # give pdf file as a derivative
    #
    # This kithe method will call `save` internally, also saving our hocr and asset model
    # changes, but doing it all in a concurrency-safe atomic way.
    asset.update_derivative(:textonly_pdf, textonly_pdf_file, allow_other_changes: true)
  ensure
    # clean up temporary files and
    if hocr_file
      hocr_file.close
      FileUtils.rm_rf(hocr_file.path)
    end

    if textonly_pdf_file
      textonly_pdf_file.close
      FileUtils.rm_rf(textonly_pdf_file.path)
    end

    FileUtils.rm_rf tempdir
  end

  # @returns [File hOCR, File textonly_pdf]
  #
  # Downloads a copy of original asset to use as tesseract input; cleans up local copy
  def get_hocr(downsample: false)
    # while some versions of tesseract can read directly from URL, the one
    # we currently have needs a local file, so we need to download it locally.
    # This is a lot slower with all the disk writing and reading.
    local_input = asset.file.download

    if downsample
      downsampled_input = downsample(local_input)

      local_input.unlink
      local_input = downsampled_input
    end

    tesseract_extract_ocr_from_local_file(local_input.path)
  ensure
    local_input&.unlink
  end

  # Downsample image by specified asset ratio and return new tempfile, using vips command line
  #
  #    `vips resize input.jpg output.jpg 0.5`
  #
  # NOTE: We do NOT set dpi metadata on downsampled image correctly to original,
  #       it's kind of a pain and we dont' think tesseract uses it?
  def downsample(input_file)
    file_suffix = TYPE_TO_SUFFIX[asset.content_type] || File.extname(asset.original_filename)
    output_tmpfile = tmpfile = Tempfile.new([self.class.name, file_suffix])
    orig_size = asset.size
    orig_dpi = asset.file_metadata["dpi"]
    orig_width = asset.width

    factor = downsample_ratio

    new_width = (orig_width * factor).round(0).to_i.to_s

    # `thumbnail` apparently works a lot better than `resize` with good defaults, fine.
    tty_command.run(
      vips_executable,
      "thumbnail",
      input_file.path,
      output_tmpfile.path,
      new_width
    )

    Rails.logger.warn("#{self.class.name}: Downsampling asset #{asset.friendlier_id} for tesseract: #{number_to_human_size orig_size} @ #{orig_dpi} dpi, #{orig_width} px wide => #{number_to_human_size output_tmpfile.size} @ #{new_width} px wide")

    return output_tmpfile
  end

  # Returns TWO values, hocr and textonly_pdf , both Files
  #
  # @param input_path local filepath of input file
  # @returns [File hOCR, File textonly_pdf]
  def tesseract_extract_ocr_from_local_file(input_path)
    unless tesseract_languages.present?
      raise TypeError.new("Work languages don't include any we can recognize: #{asset.parent.language.inspect}. We need one of #{TESS_LANGS.keys.inspect}")
    end

    result = tty_command.run(
      tesseract_executable,
      # only use first image, ignoring the embedded thumb that our production
      # process sometimes puts in
      "-c",
      "textonly_pdf=1",
      "-c",
      "tessedit_page_number=0",
      input_path,
      File.join(tempdir, BASE_OUT_FILENAME),
      "-l",
      tesseract_languages.join("+"),
      "hocr", # in hocr format
      "pdf", # and in pdf format
    )

    # sanity check
    [temp_hocr_out_path, temp_pdf_out_path].each do |expected_file|
      unless File.exist?(expected_file)
        raise RuntimeError.new("tesseract did not produce expected file at path: #{expected_file}")
      end
    end

    # okay, we have to identify the location tesseract will put the files,
    # and let's make ruby File objects out of them.
    return [File.open(temp_hocr_out_path), File.open(temp_pdf_out_path)]
  end


  private

  # lazily create a tempdir
  def tempdir
    @tempdir ||= Dir.mktmpdir("scihist_digicol_asset_hocr_creator")
  end

  # tesseract adds a suffix to the output location we told it, find it here:
  def temp_pdf_out_path
    Pathname.new(tempdir).join(BASE_OUT_FILENAME).sub_ext(".pdf").to_s
  end

  # tesseract adds a suffix to the output location we told it, find it here:
  def temp_hocr_out_path
    Pathname.new(tempdir).join(BASE_OUT_FILENAME).sub_ext(".hocr").to_s
  end

  def work_languages
    @work_languages ||= (asset.parent.language || [])
  end

  # Tesseract needs to know the expected language(s); it defaults to English.
  # We'll use our metadata languages on the associated work.
  #
  # ORDER matters for Tesseract, it's going to think they are in order of predominance
  # in the source, and use that to try to guess what things are. Our language metadata
  # may not be in that order, but it's all we have.
  def tesseract_languages
    @tesseract_languages ||= work_languages.collect { |our_lang| TESS_LANGS[our_lang] }.compact
  end

  def tty_command
    @tty_command ||= TTY::Command.new(printer: :null)
  end

end
