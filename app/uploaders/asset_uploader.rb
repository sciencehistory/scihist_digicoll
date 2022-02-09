class AssetUploader < Kithe::AssetUploader
  # gives us md5, sha1, sha512
  plugin :kithe_checksum_signatures

  # Used by our browse_everything integration, let's us set a hash with remote
  # URL location, to be fetched on promotion.
  plugin :kithe_accept_remote_url


  # use shrine upload_options plugin to set AWS tagging, only for "store" (not cache),
  # will only have effect if we are using an AWS store of course.
  plugin :scihist_upload_options, proccessor: -> (io, options, storage_key) do
    output_upload_options = {}
    # arguments that might be useful for dynamic processing including, `options[:derivative]`, true
    # if processing derivatives via shrine derivatives plugin; and `storage_key`, might be one
    # of something from config/initializers/shrine.rb.

    content_type = options.dig(:metadata, "mime_type") || "unknown"

    # AWS SDK docs: "The tag-set must be encoded as URL Query parameters. (For example, "Key1=Value1")"
    # Rails #to_query can do it for us.
    tags = {
      "Content-Type-Base" => content_type.split("/").first
      # "Content-Type-Full" => content_type
    }

    # Need the weird tagging_directive REPLACE for confusing reasons.
    # https://discourse.shrinerb.com/t/gotcha-on-s3-upload-options-and-tags/559
    output_upload_options[:tagging] = tags.to_query

    output_upload_options
  end


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
  IMAGE_DOWNLOAD_WIDTHS.each_pair do |key, derivative_width|
    Attacher.define_derivative("download_#{key}", content_type: "image") do |original_file, attacher:|
      # only create download if it would be SMALLER than original, we don't want to lossily upscale!
      if attacher.file.width > derivative_width
        Kithe::VipsCliImageToJpeg.new(max_width: derivative_width).call(original_file)
      end
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
