class AssetUploader < Kithe::AssetUploader
  # gives us md5, sha1, sha512
  plugin :kithe_checksum_signatures

  # Used by our browse_everything integration, let's us set a hash with remote
  # URL location, to be fetched on promotion.
  plugin :kithe_accept_remote_url


  # Re-set shrine derivatives setting, to put DERIVATIVES on restricted storage
  # if so configured. Only effects initial upload, if setting changes, some code
  # needs to manually move files.
  Attacher.derivatives_storage do |derivative_key|
    if record.derivative_storage_type == "restricted"
      Asset::DERIVATIVE_STORAGE_TYPE_LOCATIONS.fetch("restricted")
    else # public store
      Asset::DERIVATIVE_STORAGE_TYPE_LOCATIONS.fetch("public")
    end
  end

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
    Attacher.define_derivative("thumb_#{key}", content_type: "image") do |original_file|
      Kithe::VipsCliImageToJpeg.new(max_width: width, thumbnail_mode: true).call(original_file)
    end

    Attacher.define_derivative("thumb_#{key}", content_type: "application/pdf") do |original_file|
      Kithe::VipsCliPdfToJpeg.new(max_width: width).call(original_file)
    end

    # Double-width thumbnails
    Attacher.define_derivative("thumb_#{key}_2X", content_type: "image") do |original_file|
      Kithe::VipsCliImageToJpeg.new(max_width: width * 2, thumbnail_mode: true).call(original_file)
    end

    Attacher.define_derivative("thumb_#{key}_2X", content_type: "application/pdf") do |original_file|
      Kithe::VipsCliPdfToJpeg.new(max_width: width * 2).call(original_file)
    end
  end

  # Define download derivatives for TIFF and other image input.
  IMAGE_DOWNLOAD_WIDTHS.each_pair do |key, width|
    Attacher.define_derivative("download_#{key}", content_type: "image") do |original_file|
      Kithe::VipsCliImageToJpeg.new(max_width: width).call(original_file)
    end
  end

  # and a full size jpg
  Attacher.define_derivative("download_full", content_type: "image") do |original_file, attacher:|
    # No need to do this if our original is a JPG
    unless attacher.file.content_type == "image/jpeg"
      Kithe::VipsCliImageToJpeg.new.call(original_file)
    end
  end
end
