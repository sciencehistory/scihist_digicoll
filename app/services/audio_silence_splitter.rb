# Splits an audio file into roughly equal segments, none longer than `max_segment_length`, preferring
# to cut in the middle of a silence so that no word is split. Segments are copied without re-encoding.
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
#     AudioSilenceSplitter.new(max_segment_length: 24.minutes).split("path/to/audio.oga", duration_seconds: 7200) do |file:, start_seconds:, index:|
#       file          # => Tempfile, deleted after the block
#       start_seconds # => offset of segment in original, in (fractional) seconds, eg 2701.337
#       index         # => 0-based segment number
#     end
class AudioSilenceSplitter
  SILENCE_NOISE = "-35dB"
  SILENCE_MIN_DURATION = 0.5 # seconds

  # always leave at least this much slack below the max to search for silence (smaller for tiny max lengths)
  MIN_SEEK_WINDOW = 30 # seconds

  FILE_SUFFIX = FfmpegExtractOpusAudio::DEFAULT_FILE_SUFFIX

  class_attribute :ffmpeg_command, default: "ffmpeg"

  attr_reader :max_segment_length, :cut_point_seek_window, :log_label

  # @param max_segment_length [Numeric] hard maximum segment length in seconds (ActiveSupport durations ok)
  # @param cut_point_seek_window [Numeric] optional, how far either side of an ideal cut point to look for
  #   silence. Default 10% of segment length; always capped so no segment can exceed max_segment_length.
  # @param log_label [String] optional, identifies the audio in log messages, eg "Asset abc123"
  def initialize(max_segment_length:, cut_point_seek_window: nil, log_label: nil)
    @log_label = log_label
    @max_segment_length = max_segment_length.to_f
    @cut_point_seek_window = cut_point_seek_window&.to_f
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

  # Times in fractional seconds (Floats) at which to cut, empty if it all fits in one segment.
  #
  # Audio is divided into the fewest equal segments that fit in max_segment_length, with enough slack
  # under the max to search for silence (so an exact multiple of max gets one more segment, not hard cuts).
  # For each ideal cut point we choose the nearest silence within the seek window, or the ideal point itself if none.
  def cut_points(path, total_duration)
    total_duration = total_duration.to_f
    return [] if total_duration <= max_segment_length

    min_window = [MIN_SEEK_WINDOW, max_segment_length / 20, cut_point_seek_window].compact.min

    count = (total_duration / max_segment_length).ceil
    count += 1 while (max_segment_length - total_duration / count) / 2 < min_window

    target = total_duration / count

    # window capped so adjacent cuts can drift apart by at most (max - target), keeping every segment <= max
    window = [cut_point_seek_window || (target / 10), (max_segment_length - target) / 2].min

    silences = candidate_cut_points(path)

    (1...count).map do |i|
      ideal = target * i
      cut = silences.select { |s| (s - ideal).abs <= window }.min_by { |s| (s - ideal).abs }

      unless cut
        cut = ideal
        Rails.logger.warn("#{self.class}: #{log_label}: no silence within #{window.round(1)}s of #{ideal.round(1)}s, cutting at exact time")
      end

      cut
    end
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
