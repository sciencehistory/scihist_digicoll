# Joins several WebVTT strings into one, shifting each one's cue timestamps by an offset.
#
# Used when we split up a long file to send to whisper to transcribe, and then need
# to join the VTT that comes back.
#
# @example
#     joiner = VttJoiner.new
#     joiner.add(first_vtt)
#     joiner.add(second_vtt, offset_seconds: 2700)
#     joiner.to_joined_vtt # => "WEBVTT\n\n..."
class VttJoiner
  TIMESTAMP = /(?:\d+:)?\d{2}:\d{2}\.\d{3}/

  def initialize
    @cue_blocks = []
  end

  def add(webvtt_str, offset_seconds: 0)
    @cue_blocks << shift_cues(strip_header(webvtt_str), offset_seconds).strip
  end

  def to_joined_vtt
    "WEBVTT\n\n" + @cue_blocks.reject(&:empty?).join("\n\n") + "\n"
  end

  private

  def strip_header(webvtt_str)
    webvtt_str.sub(/\A\s*WEBVTT.*?(?:(?:\r?\n){2}|\z)/m, "")
  end

  # output timestamps are always HH:MM:SS.mmm
  def shift_cues(cues_str, offset_seconds)
    cues_str.gsub(/^(#{TIMESTAMP}) --> (#{TIMESTAMP})/) do
      "#{format_timestamp(parse_timestamp($1) + offset_seconds)} --> #{format_timestamp(parse_timestamp($2) + offset_seconds)}"
    end
  end

  def parse_timestamp(str)
    str.split(":").map(&:to_f).inject(0) { |total, part| total * 60 + part }
  end

  def format_timestamp(seconds)
    total_ms = (seconds * 1000).round
    hours, rest = total_ms.divmod(3_600_000)
    minutes, rest = rest.divmod(60_000)
    format("%02d:%02d:%02d.%03d", hours, minutes, *rest.divmod(1000))
  end
end
