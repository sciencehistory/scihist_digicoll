class Asset < Kithe::Asset
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
  define_derivative("full_jpg", content_type: "image") do |original_file, record:|
    # No need to do this if our original is a JPG
    unless record.content_type == "image/jpeg"
      Kithe::VipsCliImageToJpeg.new.call(original_file)
    end
  end

  define_derivative('mp3', content_type: "audio") do |original_file|
    Kithe::FfmpegTransformer.new(
      bitrate: '64k', force_mono: true, output_suffix: 'mp3',
    ).call(original_file)
  end
  define_derivative('webm', content_type: "audio") do |original_file|
    Kithe::FfmpegTransformer.new(
      bitrate: '64k',  force_mono: true, output_suffix: 'webm'
    ).call(original_file)
  end
end
