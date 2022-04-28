# Encapsulates the logic for launching a MediaConvert job to create
# HLS for a given video asset, via ActiveEncode, and storing it in the
# ActiveEncodeStatuses table for future progress checks.
#
#     CreateHlsMediaconvertJobService.new(asset).call
#
# ActiveEncode call will look something like this:
#
#     ActiveEncode::Base.create(
#       "s3:/",
#       {
#         use_original_url: true,
#         destination: "s3://",
#         outputs: [
#           { preset: "scihist-hls-high", modifier: "_high" },
#           { preset: "scihist-hls-medium", modifier: "_medium" },
#           { preset: "scihist-hls-low", modifier: "_low" }
#         ]
#       }
#      )
#
class CreateHlsMediaconvertJobService
  HlsPresetInfo = Struct.new(:preset_name, :name_modifier, :pixel_height,
                             keyword_init: true)

  # MediaConvert preset names we'll use to create the HLS, including
  # some metadata we may use to decide whether a given preset is
  # needed.
  #
  # SMALLEST ONE MUST BE LAST.
  HLS_PRESETS = [
    HlsPresetInfo.new(preset_name: "scihist-hls-high", name_modifier: "_high", pixel_height: 1080),
    HlsPresetInfo.new(preset_name: "scihist-hls-medium", name_modifier: "_medium", pixel_height: 720),
    HlsPresetInfo.new(preset_name: "scihist-hls-low", name_modifier: "_low", pixel_height: 480),
  ].freeze


  OUTPUT_SHRINE_STORAGE_KEY = :video_derivatives

  attr_accessor :asset

  def initialize(asset)
    unless asset
      raise ArgumentError.new("Missing required asset argument")
    end

    unless asset.content_type.start_with?("video/")
      raise ArgumentError.new("Asset must have a video file content_type, not `#{asset.file_content_type}`")
    end

    unless asset.file&.storage&.respond_to?(:bucket)
      raise ArgumentError.new("Asset must have a file in shrine S3 storage, with a `bucket` method")
    end

    @asset = asset
  end

  def call
    result = ActiveEncode::Base.create(input_s3_url,
      {
        destination: output_s3_destination,
        use_original_url: true,
        outputs: mediaconvert_outputs_arg
      }
    )
    ActiveEncodeStatus.create_from!(asset: asset, active_encode_result: result)
  end

  private

  # we need an s3:// url to pass to MediaConvert, which neither Shrine nor the AWS SDK
  # Will give us directly!
  #
  def input_s3_url
    # It is not entirely clear how to escape for URL safety in an S3 url, not
    # documented anywhere, not necessarily handled consistently by AWS...
    #
    # We'll start out doing it the same way as S3 does for http urls, just taking
    # the URL from shrine?  Note we DO need to respect shrine storage prefixes,
    # there might be a prefix in front of just the shrine `id`!
    #
    # TODO: test mediaconvert figure out escaping demands?
    @input_s3_url ||= begin
      path = URI.parse(asset.file.url(public:true)).path

      "s3://#{asset.file.storage.bucket.name}#{path}"
    end
  end

  # Where MediaConvert should put output. If we supply a prefix with a filename,
  # the main manifest output will be at that wiht a `.m3u8` on the end -- the
  # various adaptive bitrate options from the prefixes will get the `modifiers` added
  # on the end, plus `.m3u8`.
  #
  # These things are going to go in the video_derivatives bucket, we'll
  # assign paths based on asset PK UUID, similar to what we do in ordinary
  # derivatives bucket. Also a random number similar to shrine for uniqueness
  # and permanent cacheability in case we re-create differently.
  #
  # So return value will be something like:
  #
  #     s3://scihist-digicoll-production-derivatives-video/ff93bea5-dbca-4895-ae59-73fb64851fc3/bef2010a59ecad3da38c005cfcfb5747/manifest`
  #
  # And actual main manifest will be at that with `.m3u8` on the end!
  def output_s3_destination
    @output_s3_destination ||= begin
      bucket_name = Shrine.storages[OUTPUT_SHRINE_STORAGE_KEY].bucket.name

      unique_number = SecureRandom.hex

      path = "/hls/#{asset.id}/#{unique_number}/manifest"

      "s3://#{bucket_name}#{path}"
    end
  end

  def mediaconvert_outputs_arg
    presets = HLS_PRESETS
    # Unless our original is at least 90% of size of preset, don't create
    # this preset. But we always do at least the last one, which is the smallest!
    if asset.height
      presets = presets.reject { |preset| preset != presets.last && ((asset.height * 0.9) < preset.pixel_height) }
    end

    presets.map do |config|
      {
        preset: config.preset_name,
        modifier: config.name_modifier
      }
    end
  end
end
