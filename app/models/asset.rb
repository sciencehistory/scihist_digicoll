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

  # define thumb derivatives for TIFF and other image input: :thumb_mini, :thumb_mini_2X, etc.
  THUMB_WIDTHS.each_pair do |key, width|
    define_derivative("thumb_#{key}", content_type: "image") do |original_file|
      Kithe::VipsCliImageToJpeg.new(max_width: width, thumbnail_mode: true).call(original_file)
    end
    define_derivative("thumb_#{key}_2X", content_type: "image") do |original_file|
      Kithe::VipsCliImageToJpeg.new(max_width: width * 2, thumbnail_mode: true).call(original_file)
    end
  end

  # TODO define thumb derivatives for PDFs.

  # Define download derivatives for TIFF and other image input.
  IMAGE_DOWNLOAD_WIDTHS.each_pair do |key, width|
    define_derivative("download_#{key}", content_type: "image") do |original_file|
      Kithe::VipsCliImageToJpeg.new(max_width: width).call(original_file)
    end
  end

  define_derivative('mp3', content_type: "audio") do |original_file|
    Kithe::FfmpegTransformer.new(
      bitrate: '64k', stereo: false, suffix: 'mp3',
      content_type: 'audio/mpeg', codec: nil, other_options: nil
    ).call(original_file)
  end
  define_derivative('webm', content_type: "audio") do |original_file|
    Kithe::FfmpegTransformer.new(
      bitrate: '64k', stereo: false, suffix: 'webm',
      content_type: 'audio/webm', codec: 'libopus', other_options: nil
    ).call(original_file)
  end
end
