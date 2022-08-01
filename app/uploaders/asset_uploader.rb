class AssetUploader < Kithe::AssetUploader
  # gives us md5, sha1, sha512
  plugin :kithe_checksum_signatures

  # Used by our browse_everything integration, let's us set a hash with remote
  # URL location, to be fetched on promotion.
  plugin :kithe_accept_remote_url

  # store VIDEO originals in separate bucket, identified as separate shrine
  # storage ID. Instead of usual default :store shrine storage ID
  #
  # https://shrinerb.com/docs/plugins/default_storage
  plugin :default_storage
  Attacher.default_store  do
    if record.content_type&.start_with?("video/")
      :video_store
    else
      :store
    end
  end

  # audio/video file characterization
  add_metadata do |source_io, **context|
    Kithe::FfprobeCharacterization.characterize_from_uploader(source_io, context)
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


  # For FLAC originals, we create a mono m4a derivative.
  # Typically this deriv is only 5% of the size of the original FLAC,
  # while still fine for listening, at least for for oral histories.
  # (These settings would not be appropriate for audio other than recorded speech.)
  #
  # See also the settings at app/services/combined_audio_derivative_creator.rb
  # which are identical (similar use case).
  Attacher.define_derivative('m4a', content_type: "audio") do |original_file, attacher:|
    # Both audio/flac or audio/x-flac seem to be valid, so let's check for either.
    if attacher.file.content_type.match /flac$/
      Kithe::FfmpegTransformer.new(
        bitrate: '64k', force_mono: true, audio_codec: 'aac', output_suffix: 'm4a',
      ).call(original_file)
    end
  end

  # Use a standard shrine derivative processor to d some complex stuff with video thumbs,
  # including making multiple thumbs from one extraction from video.
  #
  # Tell kithe to include this processor in it's lifecycle management.

  Attacher.kithe_include_derivatives_processors += [:video_thumbs]

  # We write the logic for the video_thumbs shrine derivative processor  in kind of a confusing way,
  # first defining our shrine attacher processor as a *lambda*, then passing it as a block argument
  # to `Attacher.derivatives` with `&` -- because we really want to use `return` for flow control,
  # which we can do in a lambda but not an ordinary block argument!
  video_thumbs_processor = lambda do |original, **options|
    # bail with no derivatives unless we are a video type
    return {} unless file&.content_type&.start_with?("video/")

    # exit now with no derivs unless only/except/lazy conditions are met to generate SOME thumb derivative
    return {} unless process_any_kithe_derivative?(
      AssetUploader::THUMB_WIDTHS.keys.collect { |key| ["thumb_#{key}", "thumb_#{key}_2X"] }.flatten,
      **options
    )

    # extract the image at full scale for a base image, starting at 60 seconds
    # in if the video is long enough
    start_seconds = file.metadata["duration_seconds"].to_i >= 60 ? 60 : 0

    # Warning, frame_sample_size can use lots of RAM.
    # https://github.com/sciencehistory/scihist_digicoll/issues/1697#issuecomment-1128072969
    base_image_file = Kithe::FfmpegExtractJpg.
      new(start_seconds: start_seconds, frame_sample_size: 30).
      call(original)

    derivatives_created = {}

    # Now create all the thumbs from that one. Yes, we may be up-sampling for some
    # of these, that's fine, to have a complete set for display.
    #
    # Guard with only/except/lazy conditions for each type, assemble into one
    # hash.
    AssetUploader::THUMB_WIDTHS.each_pair do |thumb_key, width|
      if process_kithe_derivative?("thumb_#{thumb_key}", **options)
        derivatives_created["thumb_#{thumb_key}"] =
          Kithe::VipsCliImageToJpeg.new(max_width: width, thumbnail_mode: true).call(base_image_file)
      end

      if process_kithe_derivative?("thumb_#{thumb_key}_2X", **options)
        derivatives_created["thumb_#{thumb_key}_2X"] =
          Kithe::VipsCliImageToJpeg.new(max_width: width * 2, thumbnail_mode: true).call(base_image_file)
      end
    end

    derivatives_created
  ensure
    base_image_file.unlink if base_image_file && base_image_file.respond_to?(:unlink)
  end

  # We set download:false, because ffpmpeg can extract a thumb without actually
  # downloading the whole possibly huge video, so this argument keeps shrine from
  # doing the download as preparation, which keeps this much higher performance.
  Attacher.derivatives(:video_thumbs, download: false, &video_thumbs_processor)
end
