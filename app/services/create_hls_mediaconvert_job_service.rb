# Encapsulates the logic for launching a MediaConvert job to create
# HLS for a given video asset, via ActiveEncode, and storing it in the
# ActiveEncodeStatuses table for future progress checks.
#
#     CreateHlsMediaconvertJobService.new(asset).call
#
# ActiveEncode call will look something like this:
#
#     ActiveEncode::Base.create(
#       "s3://input-bucket/path/to/movie.mp4",
#       {
#         use_original_url: true,
#         destination: "s3://output-bucket/path/to/output_prefix",
#         outputs: [
#           { preset: "scihist-hls-high", modifier: "_high" },
#           { preset: "scihist-hls-medium", modifier: "_medium" },
#           { preset: "scihist-hls-low", modifier: "_low" }
#         ]
#       }
#      )
#
class CreateHlsMediaconvertJobService
  HlsPresetInfo = Struct.new(:preset_name, :name_modifier, :pixel_height, :bitrate,
                             keyword_init: true)

  # MediaConvert preset names we'll use to create the HLS, including
  # some metadata we may use to decide whether a given preset is
  # needed.
  #
  # Should be in order from smallest to largest bitrate, we sort as we define it to ensure that
  HLS_PRESETS = [
    HlsPresetInfo.new(preset_name: "scihist-hls-extra-low-with-normalization", name_modifier: "_extra_low", pixel_height: 240, bitrate: 500_000),
    HlsPresetInfo.new(preset_name: "scihist-hls-low-with-normalization", name_modifier: "_low", pixel_height: 480, bitrate: 1_500_000),
    HlsPresetInfo.new(preset_name: "scihist-hls-medium-with-normalization", name_modifier: "_medium", pixel_height: 720, bitrate: 2_500_000),
    HlsPresetInfo.new(preset_name: "scihist-hls-high-with-normalization", name_modifier: "_high", pixel_height: 1080, bitrate: 4_400_000),
  ].sort_by(&:bitrate).freeze

  OUTPUT_BASE_NAME = "hls"

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
    options = {
      destination: output_s3_destination,
      use_original_url: true,
      outputs: mediaconvert_outputs_arg
    }

    if ScihistDigicoll::Env.lookup(:storage_mode) == "dev_s3"
      # in dev_s3 storage mode, we are writing to a shared bucket that does not
      # have public read, but HLS will only be deliverable with public ACL, so tell
      # ActiveEncode to tell MediaConvert to make output public ACL.
      options[:output_group_destination_settings] = { :s3_settings => { :access_control => { :canned_acl=>"PUBLIC_READ" } } }
    end

    result = ActiveEncode::Base.create(input_s3_url, options)

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
  # the main playlist output will be at that wiht a `.m3u8` on the end -- the
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
  #     s3://scihist-digicoll-production-derivatives-video/ff93bea5-dbca-4895-ae59-73fb64851fc3/bef2010a59ecad3da38c005cfcfb5747/playlist`
  #
  # And actual main playlist will be at that with `.m3u8` on the end!
  #
  # NOTE: It's important all HLS file are put in a unique DIRECTORY, so we can
  #       delete the whole directory when we want to delete th set.
  def output_s3_destination
    @output_s3_destination ||= begin
      output_storage = Shrine.storages[OUTPUT_SHRINE_STORAGE_KEY]

      unique_number = SecureRandom.hex

      path = "/hls/#{asset.id}/#{unique_number}/#{OUTPUT_BASE_NAME}"

      if output_storage.prefix.present?
        path = "/#{output_storage.prefix.to_s}#{path}"
      end

      "s3://#{output_storage.bucket.name}#{path}"
    end
  end

  def mediaconvert_outputs_arg
    video_bitrate = asset.file&.metadata&.dig("video_bitrate")

    presets = HLS_PRESETS

    # if we know either asset bitrate or heihgt, we can avoid unneeded too-large presets.
    #
    # We always need the lowest preset at least (we count on them being in order),
    # and then only the video goes over a preset do we need the next.
    if video_bitrate || asset.height
      presets = []

      HLS_PRESETS.each do |preset|

        presets << preset
        if !(  (asset.height.nil? || asset.height > preset.pixel_height) ||
               (video_bitrate.nil?  || video_bitrate > preset.bitrate)
            )
          break
        end
      end
    end

    presets.map do |config|
      {
        preset: config.preset_name,
        modifier: config.name_modifier
      }
    end
  end
end
