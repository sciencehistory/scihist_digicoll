module OralHistory
  class VttTranscriptComponent < ApplicationComponent
    delegate :format_ohms_timestamp, to: :helpers

    def initialize(vtt_transcript)
      @vtt_transcript = vtt_transcript
    end

    def display_paragraphs
      last_speaker = nil # don't do same speaker twice in a row
      @vtt_transcript.cues.each do |cue|
        start_sec_f = cue.start_sec_f # we only want to do this once per cue
        cue.paragraphs.each do |paragraph|
          yield start_sec_f, (paragraph.speaker_name if paragraph.speaker_name != last_speaker), paragraph.safe_html
          last_speaker = paragraph.speaker_name
          start_sec_f = nil
        end
      end
    end

  end
end
