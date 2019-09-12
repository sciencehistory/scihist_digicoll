class Asset < Kithe::Asset

  has_many :fixity_checks, foreign_key: "asset_id", inverse_of: "asset", dependent: :destroy

  THUMB_WIDTHS = {
    mini: 54,
    large: 525,
    standard: 208
  }

  IMAGE_DOWNLOAD_WIDTHS = {
    large: 2880,
    medium: 1200,
    small: 800
  }

  # define thumb derivatives for TIFF, PDF, and other image input: :thumb_mini, :thumb_mini_2X, etc.
  THUMB_WIDTHS.each_pair do |key, width|
    # Single-width thumbnails
    define_derivative("thumb_#{key}", content_type: "image") do |original_file|
      Kithe::VipsCliImageToJpeg.new(max_width: width, thumbnail_mode: true).call(original_file)
    end
    define_derivative("thumb_#{key}", content_type: "application/pdf") do |original_file|
      Kithe::VipsCliPdfToJpeg.new(max_width: width).call(original_file)
    end
    # Double-width thumbnails
    define_derivative("thumb_#{key}_2X", content_type: "image") do |original_file|
      Kithe::VipsCliImageToJpeg.new(max_width: width * 2, thumbnail_mode: true).call(original_file)
    end
    define_derivative("thumb_#{key}_2X", content_type: "application/pdf") do |original_file|
      Kithe::VipsCliPdfToJpeg.new(max_width: width * 2).call(original_file)
    end
  end

  # Define download derivatives for TIFF and other image input.
  IMAGE_DOWNLOAD_WIDTHS.each_pair do |key, width|
    define_derivative("download_#{key}", content_type: "image") do |original_file|
      Kithe::VipsCliImageToJpeg.new(max_width: width).call(original_file)
    end
  end

  # and a full size jpg
  define_derivative("download_full", content_type: "image") do |original_file, record:|
    # No need to do this if our original is a JPG
    unless record.content_type == "image/jpeg"
      Kithe::VipsCliImageToJpeg.new.call(original_file)
    end
  end

  # mono and 64k bitrate, nice and small, good enough for our voice-only
  # Oral History interviews we're targetting. Our original might have been FLAC
  # or might have been a probably larger MP3.
  define_derivative('small_mp3', content_type: "audio") do |original_file|
    Kithe::FfmpegTransformer.new(
      bitrate: '64k', force_mono: true, output_suffix: 'mp3',
    ).call(original_file)
  end
  define_derivative('webm', content_type: "audio") do |original_file|
    Kithe::FfmpegTransformer.new(
      bitrate: '64k',  force_mono: true, output_suffix: 'webm'
    ).call(original_file)
  end

  # Our DziFiles object to manage associated DZI (deep zoom, for OpenSeadragon
  # panning/zooming) file(s).
  #
  #     asset.dzi_file.url # url to manifest file
  #     asset.dzi_file.exists?
  #     asset.dzi_file.create # normally handled by automatic lifecycle hooks
  #     asset.dzi_file.delete # normally handled by automatic lifecycle hooks
  def dzi_file
    @dzi_file ||= DziFiles.new(self)
  end

  after_promotion DziFiles, if: ->(asset) { asset.content_type&.start_with?("image/") }
  after_commit DziFiles, only: [:update, :destroy]
end
