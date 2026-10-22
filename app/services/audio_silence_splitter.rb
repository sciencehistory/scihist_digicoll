# Splits an audio file into segments of roughly `segment_target_length`, preferring to cut in the
# middle of a silence so that no word is split. Segments are copied without re-encoding.
#
# We use ffmpeg to identify silent moments, and try to split on a silent moment.
#
# This is used for splitting long audio recordings before whisper transcription.
#
# Each segment is yielded successively.
#
# All times are in seconds, as Floats with fractional (millisecond-ish) precision, as
# reported by ffmpeg -- not whole seconds.
#
# @example
#     AudioSilenceSplitter.new(segment_target_length: 45.minutes).split("path/to/audio.oga", duration_seconds: 7200) do |file:, start_seconds:, index:|
#       file          # => Tempfile, deleted after the block
#       start_seconds # => offset of segment in original, in (fractional) seconds, eg 2701.337
#       index         # => 0-based segment number
#     end
class AudioSilenceSplitter
  SILENCE_NOISE = "-35dB"
  SILENCE_MIN_DURATION = 0.5 # seconds

  FILE_SUFFIX = FfmpegExtractOpusAudio::DEFAULT_FILE_SUFFIX

  class_attribute :ffmpeg_command, default: "ffmpeg"

  attr_reader :segment_target_length, :cut_point_seek_window, :log_label

  # @param segment_target_length [Numeric] target segment length in seconds (ActiveSupport durations ok)
  # @param cut_point_seek_window [Numeric] how far either side of the target cut point to look for silence
  # @param log_label [String] optional, identifies the audio in log messages, eg "Asset abc123"
  def initialize(segment_target_length:, cut_point_seek_window: nil, log_label: nil)
    @log_label = log_label
    @segment_target_length = segment_target_length.to_f
    @cut_point_seek_window = cut_point_seek_window ? cut_point_seek_window.to_f : (@segment_target_length / 10)
  end

  # Yields each segment (keywords file:, start_seconds:, index:) in order; the Tempfile is deleted after its block returns.
  def split(path, duration_seconds:, &block)
    cuts = cut_points(path, duration_seconds)
    starts = [0.0] + cuts
    ends = cuts + [nil]

    starts.zip(ends).each_with_index do |(start, finish), index|
      tempfile = Tempfile.new(["audio_segment", FILE_SUFFIX])
      begin
        extract_segment(path, tempfile.path, start: start, length: (finish - start if finish))
        block.call(file: tempfile, start_seconds: start, index: index)
      ensure
        tempfile.close!
      end
    end
  end

  # Times in fractional seconds (Floats) at which to cut, aiming for every segment_target_length, empty if it all fits in one segment.
  #
  # There are many silences in an audio file, we only want a few cuts: for each segment_target_length
  # target, we choose the silence closest to it (within cut_point_seek_window), or the
  # target itself if there is none.
  def cut_points(path, total_duration)
    return [] if total_duration <= segment_target_length

    silences = candidate_cut_points(path)
    cuts = []
    start = 0.0

    while total_duration - start > segment_target_length
      target = start + segment_target_length
      nearby = silences.select { |s| (s - target).abs <= cut_point_seek_window && s > start }
      cut = nearby.min_by { |s| (s - target).abs }

      unless cut
        cut = target
        Rails.logger.warn("#{self.class}: #{log_label}: no silence within #{cut_point_seek_window.round}s of #{target.round(1)}s, cutting at exact time")
      end

      cuts << cut
      start = cut
    end

    cuts
  end

  private

  # middle of every silence found in the file, in seconds (including fractional seconds)
  def candidate_cut_points(path)
    _out, err = TTY::Command.new(printer: :null).run(
      ffmpeg_command, "-nostdin", "-i", path.to_s, "-vn",
      "-af", "silencedetect=noise=#{SILENCE_NOISE}:d=#{SILENCE_MIN_DURATION}",
      "-f", "null", "-"
    )

    # start/end pairs in order, from lines like "silence_start: 4.0167" then "silence_end: 6.0137 | ...".
    # A final silence still going at end of file has no end, and is not matched.
    err.scan(/silence_start: (-?[\d.]+).*?silence_end: (-?[\d.]+)/m).map do |start, finish|
      (start.to_f.clamp(0, finish.to_f) + finish.to_f) / 2
    end
  end

  # copy `length` seconds (to the end if nil) from `start` into output_path, without re-encoding
  def extract_segment(path, output_path, start:, length:)
    args = [ffmpeg_command, "-nostdin", "-y", "-ss", start.to_s, "-i", path.to_s]
    args += ["-t", length.to_s] if length
    args += ["-vn", "-c", "copy", output_path]

    TTY::Command.new(printer: :null).run(*args)
  end
end
