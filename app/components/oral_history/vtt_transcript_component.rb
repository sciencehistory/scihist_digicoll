module OralHistory
  class VttTranscriptComponent < ApplicationComponent
    delegate :format_ohms_timestamp, to: :helpers

    FootnoteTextScrubber = Rails::Html::PermitScrubber.new.tap do |scrubber|
      scrubber.tags = ['i', 'b', 'u', 'a']
    end

    attr_reader :vtt_transcript, :base_link

    # @param vtt_transcript [OralHistoryContent::OhmsXml::VttTranscript]
    #
    # @param base_link [String] if you want timestamps to link to a separate page, with
    #   anchor on end. If blank, will just have href to same page with anchor, to be
    #   picked up by JS.
    def initialize(vtt_transcript, base_link: nil)
      @vtt_transcript = vtt_transcript
      @base_link = base_link
    end

    def sanitized_footnotes
      @sanitized_footnotes ||= vtt_transcript.footnotes.collect { |ref, text| [ref, scrub_footnote_text(text)] }.to_h
    end


    # Takes scrubbed OHMS VTT HTML text with prepared `<c cref="N">` tags, and
    # replaces with rendered footnote references.
    def render_footnote_tags(str)
      # And now we need to turn those <c> tags into our footnote reference links!
      # Note non-greedy regex match '+?' or '*?' operator so it gets first </c>. They can't be nested!
      str.gsub!(/<c cref=(?:"|')(\d+)(?:"|')[^>]*>(.+?)<\/c>/) do |_matched|
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
        cue.paragraphs.each do |paragraph|
          paragraph_safe_html = render_footnote_tags(paragraph.scrubbed_ohms_vtt_html)
          paragraph_speaker_name = (paragraph.speaker_name || paragraph.assumed_speaker_name)

          yield(
            start_seconds: paragraph.included_timestamps&.first,
            speaker_name: (paragraph_speaker_name if paragraph_speaker_name != last_speaker),
            html_text: paragraph_safe_html,
            fragment_id: paragraph.fragment_id
          )

          last_speaker = paragraph_speaker_name
          start_sec_f = nil
        end
      end
    end
  end
end
