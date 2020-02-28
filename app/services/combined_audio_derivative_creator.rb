require 'tempfile'
#
# Generate the combined audio derivatives for a
# given oral history work.
#
# some_work = Work.find_by_friendlier_id(friendlier_id)
# CombinedAudioDerivativeCreator.new(some_work).generate
#
#
# Sample output:
    # {
    #   :combined_audio_mp3_data=>
    #   "/var/folders/n7/t4zt2w751bj_6pbnf95sgpnrmz8lz8/T/output20200228-61637-ec6kjz.mp3",
    #  :combined_audio_webm_data=>
    #   "/var/folders/n7/t4zt2w751bj_6pbnf95sgpnrmz8lz8/T/output20200228-61637-1btjscz.webm",
    #  :fingerprint=>"4998d366f5edb6222db1181c7b153e21",
    #  :component_metadata=>
    #   {:durations=>["00:30:30.29", "00:29:13.32", "00:33:03.26", "00:24:28.94"]}
    # }

class CombinedAudioDerivativeCreator

  attr_reader :work

  def initialize(work)
    @cmd = TTY::Command.new(printer: :null)
    @work = work
    @downloaded_originals = []
  end

  def generate
    # Start by downloading all the audio files:
    download_originals

    # Figure out how long each component lasts:
    component_durations = @downloaded_originals.map do |f|
      duration_of_audio_file(f.path)
    end

    # Generate two empty audio files, which will be overwritten by the ffmpeg commands:
    mp3_output_file  = Tempfile.new(['output',  ".mp3"], :encoding => 'binary')
    webm_output_file = Tempfile.new(['output', ".webm"], :encoding => 'binary')

    # Generate the command arguments for ffmpeg:
    mp3_ffmpeg_args = args_for_ffmpeg(mp3_output_file.path)
    webm_ffmpeg_args = args_for_ffmpeg(webm_output_file.path)

    # Run the commands:
    log "Creating mp3 using command:"
    log(mp3_ffmpeg_args.join(" "))
    @cmd.run(*mp3_ffmpeg_args,  binmode: true)

    log "Creating webm using command: "
    log(webm_ffmpeg_args.join(" "))
    @cmd.run(*webm_ffmpeg_args, binmode: true)

    # Get rid of the downloaded originals:
    @downloaded_originals.map!(&:unlink)

    {
      combined_audio_mp3_data:  mp3_output_file.path,
      combined_audio_webm_data: webm_output_file.path,
      fingerprint: fingerprint,
      component_metadata: {durations: component_durations}
    }
  end

  def duration_of_audio_file(path)
    (@cmd.run(*['ffprobe', path]).err.match /Duration: ([^,]*),/)[1]
  end

  def download_originals
    audio_member_files.each do |original_file|
      log "Downloading #{original_file.metadata['filename']}"
      new_temp_file = Tempfile.new(['temp_', original_file.metadata['filename'].downcase], :encoding => 'binary')
      original_file.open(rewindable:false) do |input_audio_io|
        new_temp_file.write input_audio_io.read until input_audio_io.eof?
      end
      @downloaded_originals << new_temp_file
    end
  end

  # Generate ffmpeg command to concatenate a set of audio files using
  # ffmpeg stream mapping.
  # This is tricky but documented at
  # https://trac.ffmpeg.org/wiki/Map .
  # For now, the audio settings are hardwired.
  def args_for_ffmpeg(output_file_path)
    # ffmpeg -y: overwrite the already-existing temp file
    ffmpeg_command = ['ffmpeg', '-y']

    # Then a list of input files specified with -i
    input_files = @downloaded_originals.map {|x| [ "-i", x.path] }.flatten

    # List the number of audio streams: one per file
    stream_list = 0.upto(@downloaded_originals.count - 1).to_a.map{ |n| "[#{n}:a]"}.join

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
    filtergraph = "concat=n=#{@downloaded_originals.count}:v=0:a=1[a]"

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

  def audio_member_files
    audio_members.map { |asset| asset.file }
  end

  # Filters out non-audio items
  def audio_members
    work.members.order(:position, :id).select do |member|
      member.stored? && member.file.mime_type.start_with?('audio')
    end
  end

  # If this checksum changes, you need to regenerate the audio
  def fingerprint
    @calculated_checksum ||= begin
      parts = [work.title, work.friendlier_id] +
        audio_members.map { |a| a.file.metadata['sha512'][0..10] }
      Digest::MD5.hexdigest(parts.join)
    end
  end

  def log(x)
    puts (x)
  end
end
