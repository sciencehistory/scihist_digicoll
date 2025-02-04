module OralHistory
  class VttTranscriptComponent < ApplicationComponent
    delegate :format_ohms_timestamp, to: :helpers

    TextScrubber = Rails::Html::PermitScrubber.new.tap do |scrubber|
      # 'c' is WebVTT 'class' object, which we only expect in the form
      # of c.1, c.12 etc for OHMS annotation references.
      scrubber.tags = ['i', 'b', 'u', 'c']
      scrubber.attributes = ['cref'] # for our weird custom c tag
    end

    FootnoteTextScrubber = Rails::Html::PermitScrubber.new.tap do |scrubber|
      scrubber.tags = ['i', 'b', 'u', 'a']
    end

    attr_reader :vtt_transcript

    def initialize(vtt_transcript)
      @vtt_transcript = vtt_transcript
    end

    def sanitized_footnotes
      @sanitized_footnotes ||= vtt_transcript.footnotes.collect { |ref, text| [ref, scrub_footnote_text(text)] }.to_h
    end

    # Replace the VTT <c.N> tags used by OHMS for annotation/footnote references
    # with our footnote <a> tags.
    #
    # And html sanitize the rest
    def scrub_text(raw_html)
      # Turn <c.1> tags to XML-legal <c ref='1'> tags with the one in a ref attribute
      str = raw_html.gsub(/<c\.(\d+)/, "<c cref='\\1'")

      str = Loofah.fragment(str).
        scrub!(TextScrubber).
        to_s

      # And now we need to turn those <c> tags into our footnote reference links!
      # Note non-greedy regex match '+?' or '*?' operator so it gets first </c>. They can't be nested!
      str.gsub!(/<c cref="(\d+)"[^>]*>(.+?)<\/c>/) do |_matched|
        refNum = $1
        inner_content = $2.html_safe

        render(OralHistory::FootnoteReferenceComponent.new(
          footnote_text: sanitized_footnotes[refNum],
          footnote_is_html: true,
          number: refNum,
          link_content: inner_content
        ))
      end

      # we have sanitized and replaced with a component, it should be html_safe
      str.html_safe
    end

    # Footnote text, unlike our main text, can have links, but
    # we want to ensure they all have rel=opener and target=_blank set
    # (Which some built-in scrubbers in Loofah can do)
    #
    def scrub_footnote_text(raw_html)
      str = Loofah.fragment(raw_html).
        scrub!(FootnoteTextScrubber).
        scrub!(:targetblank).
        scrub!(:noopener).
        to_s.html_safe
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
