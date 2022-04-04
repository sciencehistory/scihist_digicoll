require 'tempfile'


#
# Generate the combined audio derivatives for a
# given oral history work.
#
# some_work = Work.find_by_friendlier_id(friendlier_id)
# CombinedAudioDerivativeCreator.new(some_work).generate
#
# Returns a struct in which webm_file and mp3_file each refers to a TempFile.
#
# Sample output:
# <struct Response
#  webm_file=<File:/path/to/file.webm>,
#  mp3_file=<File:/path/to/file.mp3>,
#  fingerprint="e0248c40015d6dc90b0d02937950b5d7",
#  start_times=
#   [["ddbd1a8d-c2eb-47b3-85a4-11b4ffb41719", 0],
#    ["df773502-56d7-4756-a58c-b1f479910e97", 1.593469]]
#  >
#
class CombinedAudioDerivativeCreator

  Response = Struct.new(:webm_file, :mp3_file, :fingerprint, :start_times, :errors, keyword_init: true)

  attr_reader :work, :logger

  def initialize(work, logger: Rails.logger)
    @work = work
    @logger = logger
  end

  def generate
    if input_sources.length == 0
      return Response.new(errors: "Could not assemble all the input sources.")
    end
    output_files = {}
    # Create the two output files:
    ['mp3', 'webm'].each do |format|
      output_files[format] = output_file(format)
      ffmpeg_args = args_for_ffmpeg(output_files[format].path)
      cmd.run(*ffmpeg_args, binmode: true, only_output_on_error: true)
    end
    resp = Response.new
    resp.webm_file   = output_files['webm']
    resp.mp3_file    = output_files['mp3']
    resp.fingerprint = fingerprint
    resp.start_times = calculate_start_times
    resp
  ensure
    # Before leaving, get rid of the downloaded originals:
    input_tempfiles.map!(&:unlink)
    input_tempfiles.clear
    input_sources.clear
  end


  def cmd
    @cmd ||= TTY::Command.new(output: TtyLoggerWrapper.new(logger))
  end

  def output_file(format)
    Tempfile.new(['output', ".#{format}"], :encoding => 'binary')
  end

  # Use ffprobe to determine the length of an audio file.
  def duration_of_audio_file_in_seconds(path)
    options = ['ffprobe', '-v', 'error',
      '-show_entries', 'format=duration', '-of',
      'default=noprint_wrappers=1:nokey=1'
    ] + [ path ]
    cmd.run(*options).out.strip.to_f
  end

  def input_tempfiles
    @input_tempfiles = []
  end

  # an array of args to ffmpeg for the input files, will be URLs if possible, otherwise
  # local file paths from temporarily downloaded local files.
  def input_sources
    @input_args ||= begin
      logger.debug("#{self.class}: downloading original assets")

      audio_member_files.collect do |original_file|
        if original_file.url.present? && original_file.url.start_with?(/https?:/)
          original_file.url(expires_in: 48.hours.to_i)
        else
          new_temp_file = original_file.download(rewindable: false)
          input_tempfiles << new_temp_file
          new_temp_file.path
        end
      end.tap do
        logger.debug("#{self.class}: downloading original assets complete")
      end
    end
  end

  # A list of arrays; the first item in each is the UUID of each audio member,
  # while the second is the *starting point* of that audio w/r/t the combined audio.
  #
  # The durations are obtained from stored characterization metadata, we count on that
  # being present and correct!
  def calculate_start_times
    duration_map = published_audio_members.collect do |audio_asset|
      [audio_asset.id, audio_asset.file&.metadata&.dig("duration_seconds")]
    end.to_h

    sum = 0
    end_points = duration_map.values.map {|i| sum += i.to_f }.map { |i| i.round(3) }

    duration_map.keys.zip([0] + end_points)
  end

  # Generate ffmpeg command to concatenate a set of audio files using
  # ffmpeg stream mapping.
  # This is tricky but documented at
  # https://trac.ffmpeg.org/wiki/Map and https://trac.ffmpeg.org/wiki/Concatenate#protocol
  #
  # For now, the audio settings are hardwired.
  # This does not run the command; it just returns
  # an array that can be passed to cmd.run .
  #
  def args_for_ffmpeg(output_file_path)
    # ffmpeg -y: overwrite the already-existing temp file
    ffmpeg_command = ['ffmpeg', '-y']

    # Then a list of input URLs or file paths specified with -i
    input_files = input_sources.map {|x| [ "-i", x] }.flatten

    # List the number of audio streams: one per file
    stream_list = 0.upto(input_sources.count - 1).to_a.map{ |n| "[#{n}:a]"}.join

    # Specify what to do with the audio streams:
    #
    # Stream mapping:
    #   Stream #0:0 (mp3float) -> concat:in0:a0
    #   Stream #1:0 (mp3float) -> concat:in1:a0
    #   Stream #2:0 (mp3float) -> concat:in2:a0
    #   [ and so on]
    #   concat -> Stream #0:0 (libmp3lame)
    #
    # v=0 means there is no video.
    filtergraph = "concat=n=#{input_sources.count}:v=0:a=1[a]"

    # Finally, some output options:
    # -map [a] : map just the audio to the output
    #
    # -ac 1 : output should be mono
    #    see https://trac.ffmpeg.org/wiki/AudioChannelManipulation
    # -b:a 64K: make the output a constant 64k bitrate
    #    see https://trac.ffmpeg.org/wiki/Encode/MP3
    output_quality = ["-map", "[a]", "-ac", "1", "-b:a", "64k"]

    # Put it all together and return:
    ffmpeg_command +
      input_files +
      ['-filter_complex'] +
      ["#{stream_list}#{filtergraph}"] +
      output_quality +
      [output_file_path]
  end

  def available_members?
    published_audio_members.present?
  end

  def available_members_count
    published_audio_members.count
  end

  def audio_member_files
    published_audio_members.map { |asset| asset.file }
  end

  # If this checksum changes, you need to regenerate the audio
  def fingerprint
    @fingerprint ||= begin
      digests = published_audio_members.map(&:sha512).compact
      uuids   = published_audio_members.pluck(:id)
      unless digests.length == published_audio_members.length
        raise RuntimeError, 'This item is missing a sha512'
      end
      Digest::MD5.hexdigest((
        [work.title, work.friendlier_id] + digests + uuids
      ).join)
    end
  end

  private
    # Filters out non-audio and unpublished items
    def published_audio_members
      @published_audio_members ||= begin
        work.members.order(:position, :id).select do |member|
          (member.is_a? Asset) && member.published? && member.stored? && member.content_type && member.content_type.start_with?("audio/")
        end
      end
    end

    # TTY:::Command wants a logger that uses method `<<`. We want
    # that to go to specific chosen level of logging in our Rails logger.
    #
    # Also TTY log messages have newlines that are better off removed.
    class TtyLoggerWrapper
      def initialize(wrapped_logger, level: :info)
        @wrapped_logger = wrapped_logger
        @level = level
      end
      def <<(str)
        @wrapped_logger.send(@level, str.chomp)
      end
    end

end
