require 'docx'
require 'tempfile'


# Patch to Docx gem to give us substitute_block, where we can supply a block that
# has access to regexp match data, with captures.
#
# See https://github.com/ruby-docx/docx/pulls
#
# docx gem may not currently be maintained, this may not ever be merged upstream.

SanePatch.patch('docx', '0.8.0') do
  require 'docx/document'
  class Docx::Elements::Containers::TextRun
    def substitute_block(match, &block)
      @text_nodes.each do |text_node|
        text_node.content = text_node.content.gsub(match) { |_unused_matched_string|
          block.call(Regexp.last_match)
        }
      end
      reset_text
    end
  end
end

# arithematically alter timestamps in multi-part joined Oral History transcripts to be in proper sequence
class SequenceOhTimestamps
  attr_reader :transcript_docx, :file_start_times


  # @param transcript_docx_file [String,File] path or File object pointing to a .docx transcript with timestamps
  #
  # @param file_start_times [Hash] as if might come from metadata 'start_times' in an
  #   oral_history_content&.combined_audio_component_metadata. Eg
  #       {
  #          uuid  => 0,
  #          uuid1 => 2837,
  #          uuid2 => 3723
  #       }
  #
  #    The key uuid is actually ignored, but the ORDER in hash matters, to represent
  #    actual order of files.
  def initialize(transcript_docx_file, file_start_times)
    @transcript_docx = Docx::Document.open(transcript_docx_file)
    @file_start_times = file_start_times
  end

  # @return [Tempfile] docx with timecodes adjusted
  def process
    file_index = 0

    transcript_docx.paragraphs.each do |paragraph|
      if paragraph.text =~ /\[END OF AUDIO, FILE .*\]/
        file_index += 1
        next
      end

      if file_index == 0
        next
      end

      paragraph.each_text_run do |text_run|
        text_run.substitute_block(/\[(\d+):(\d\d):(\d\d)(?:\.(\d+))?\]/) do |match_data|
          hours, minutes, seconds, fractional_seconds = match_data[1].to_i, match_data[2].to_i, match_data[3].to_i, match_data[4].to_f
          timecode_seconds = seconds + (minutes * 60) + (hours * 60 * 60)

          if fractional_seconds != 0
            timecode_seconds = timecode_seconds + fractional_seconds
          end

          # assume the hash is ordered, so we take the ith key, and find the start time for it
          # to add on
          timecode_seconds += file_start_times[ file_start_times.keys[file_index] ]

          "[#{OhmsHelper.format_ohms_timestamp(timecode_seconds)}]"
        end
      end
    end

    if file_index != file_start_times.count
      byebug
      raise "Uh oh mismatch"
    end

    tmpfile = Tempfile.new([self.class.name, ".docx"])
    transcript_docx.save(tmpfile.path)

    return tmpfile
  end


  def audio_members
    @audio_members ||= work.members.order(:position).strict_loading.to_a.select do |m|
      m.asset? && m.leaf_representative&.content_type&.start_with?("audio/")
    end
  end

  # An array of start times for each audio member.
  # The key is the member uuid (NOT the friendlier id)
  # The value is the offset in seconds into the combined audio.
  # The first value in the array, if there is one,
  # should ALWAYS be zero.
  def start_times
    @start_times ||= begin
      metadata = work&.oral_history_content&.combined_audio_component_metadata
      metadata ? metadata['start_times'].to_h : {}
    end
  end
end
