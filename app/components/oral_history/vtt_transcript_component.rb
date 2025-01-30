module OralHistory
  class VttTranscriptComponent < ApplicationComponent
    delegate :format_ohms_timestamp, to: :helpers

    TextScrubber = Rails::Html::PermitScrubber.new.tap do |scrubber|
      scrubber.tags = ['i', 'b', 'u']
    end

    def initialize(vtt_transcript)
      @vtt_transcript = vtt_transcript
    end

    def scrub_text(raw_html)
      Loofah.fragment(raw_html).
        tap { |frag| frag.scrub!(TextScrubber) }.
        then { |frag| frag.to_s.strip.html_safe }
    end

    def display_paragraphs
      last_speaker = nil # don't do same speaker twice in a row
      @vtt_transcript.cues.each do |cue|
        start_sec_f = cue.start_sec_f # we only want to do this once per cue
                                      #
        cue.paragraphs.each do |paragraph|
          paragraph_safe_html = scrub_text(paragraph.raw_html)

          yield start_sec_f, (paragraph.speaker_name if paragraph.speaker_name != last_speaker), paragraph_safe_html
          last_speaker = paragraph.speaker_name
          start_sec_f = nil
        end
      end
    end

  end
end
