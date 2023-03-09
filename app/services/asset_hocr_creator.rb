# For a specific asset, run image through OCR with tesseract, to get HOCR output,
# attach to asset.
#
# Will overwrite any existing #hocr on asset, will run whether or not there is existing.
#
# * We run on the full-res TIFF, although this is slower, it will give us best results.
#
# * While some versions of tesseract are supposed to be able to read directly from URI,
#   the 4.1.1 we currently have on heroku cannot, so we have to download temp copy,
#   which does make this even slower. (Wait, should we pipe curl to it instead?)
class AssetHocrCreator
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
    asset.hocr = get_hocr
    asset.save!
  end

  def get_hocr
    # while some versions of tesseract can read directly from URL, the one
    # we currently have needs a local file, so we need to download it locally.
    # This is a lot slower with all the disk writing and reading.
    local_original = asset.file.download

    tesseract_extract_hocr_from_local_file(local_original.path)
  ensure
    local_original&.unlink
  end

  # @param input_path local filepath of input file
  # @returns String hOCR
  def tesseract_extract_hocr_from_local_file(input_path)
    unless tesseract_languages.present?
      raise TypeError.new("Work languages don't include any we can recognize: #{work.languages.inspect}. We need one of #{TESS_LANGS.keys.inspect}")
    end

    result = tty_command.run(
      tesseract_executable,
      # only use first image, ignoring the embedded thumb that our production
      # process sometimes puts in
      "-c",
      "tessedit_page_number=0",
      input_path,
      # output to stdout
      "-",
      "-l",
      tesseract_languages.join("+"),
      "hocr" # in hocr format
    )

    result.stdout
  end


  private

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
