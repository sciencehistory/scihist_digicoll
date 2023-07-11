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
class AssetHocrCreator
  BASE_OUT_FILENAME = "tesseract_out"

  class_attribute :tesseract_executable, default: "tesseract"

  # key is language in our metadata language field, value
  # is language as tesseract labels it. For languages we
  # currently handle.
  TESS_LANGS = {
    "English" => "eng",
    "German"  => "deu",
    "French"  => "fra",
    "Spanish" => "spa"
  }.freeze

  attr_accessor :asset

  def initialize(asset)
    unless asset&.content_type&.start_with?("image/")
      raise ArgumentError, "Can only use with content type begining `image/`, not #{asset.content_type}"
    end

    @asset = asset
  end

  def call
    hocr_file, textonly_pdf_file = get_hocr

    # read hocr file into string to set as json attribute
    asset.hocr = hocr_file.read

    # give pdf file as a derivative
    #
    # This kithe method will call `save` internally, also saving our hocr
    # change, but doing it all in a concurrency-safe atomic way.
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

  def get_hocr
    # while some versions of tesseract can read directly from URL, the one
    # we currently have needs a local file, so we need to download it locally.
    # This is a lot slower with all the disk writing and reading.
    local_original = asset.file.download

    tesseract_extract_ocr_from_local_file(local_original.path)
  ensure
    local_original&.unlink
  end

  # Returns TWO values, hocr and textonly_pdf , both Files
  #
  # @param input_path local filepath of input file
  # @returns [File hOCR, File textonly_pdf]
  def tesseract_extract_ocr_from_local_file(input_path)
    unless tesseract_languages.present?
      raise TypeError.new("Work languages don't include any we can recognize: #{asset.parent.languages.inspect}. We need one of #{TESS_LANGS.keys.inspect}")
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
