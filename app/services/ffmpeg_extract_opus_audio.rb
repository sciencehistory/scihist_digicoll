# We use for getting audio out of a video to send to OpenAI Whisper API --
#
# So the defaults are fairly low bitrate, choosing opus "voip" preset for speech-oriented
# audio. We need a small file for OpenAI file size limits, we don't need very high quality,
# and in fact some people say lower birrate works BETTER.
#
# While set up for use with kithe derivatives, you can def also just use it separate, and
# we likely will!
#
# @example
#     FfmpegExtractLofiOpusAudio.new.call("path/to/audio_or_video.mp4")
class FfmpegExtractOpusAudio
  class_attribute :ffmpeg_command, default: "ffmpeg"

  DEFAULT_BITRATE = "16k"
  DEFAULT_OPUS_APPLICATION = "voip" # can be `voip` `audio` (default) or `lowdelay`
  DEFAULT_FILE_SUFFIX = ".oga" # while some like .opus for opus in OGG, OpenAI can't handle it needs `.oga` ogg audio

  attr_reader :bitrate_arg, :opus_application, :file_suffix

  def initialize(bitrate_arg: DEFAULT_BITRATE, opus_application: DEFAULT_OPUS_APPLICATION, file_suffix: DEFAULT_FILE_SUFFIX)
    @bitrate_arg = bitrate_arg
    @opus_application = opus_application
    @file_suffix = file_suffix
  end

  # add_metadata param can be used with kithe derivative definitions, to supply
  # additional provenance metadata
  #
  # @param input_arg[Shrine::UploadedFile,String] if String, should be path to a file on disk. If
  #   Shrine::UploadedFile, we will download it either directly or by giving a url to ffmpeg.
  #   File can be any audio-containing format ffmpeg can handle (including video)
  def call(input_arg, add_metadata:nil)
    if input_arg.kind_of?(Shrine::UploadedFile)
      if input_arg.respond_to?(:url) && input_arg.url&.start_with?(/https?\:/)
        _call(input_arg.url, add_metadata: add_metadata)
      else
        Shrine.with_file(input_arg) do |local_file|
          _call(local_file.path, add_metadata: add_metadata)
        end
      end
    elsif input_arg.respond_to?(:path)
      _call(input_arg.path, add_metadata: add_metadata)
    else
      _call(input_arg.to_s, add_metadata: add_metadata)
    end
  end

  private

  def _call(ffmpeg_source_arg, add_metadata: nil)
    tempfile = Tempfile.new([self.class.name, file_suffix])

    ffmpeg_args = produce_ffmpeg_args(input_arg: ffmpeg_source_arg, output_path: tempfile.path)
    out, err = TTY::Command.new(printer: :null).run(*ffmpeg_args)

    if add_metadata
      add_metadata[:ffmpeg_command] = ffmpeg_args.join(" ")

      err =~ /ffmpeg version (\d+\.\d+(\.\d+)?)/i
      if $1
        add_metadata[:ffmpeg_version] = $1
      end
    end

    return tempfile
  end

  def produce_ffmpeg_args(input_arg:, output_path:)
    [
      ffmpeg_command,
      "-nostdin", "-y",
      "-i", input_arg,
      "-vn", # no video
      "-map_metadata", "-1", # do not copy metadata
      "-ac", "1", # one audio channel
      "-c:a", "libopus",
      "-b:a", bitrate_arg,
      "-application", opus_application,
      output_path
    ]
  end


end
