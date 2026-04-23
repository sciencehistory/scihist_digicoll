module OralHistory
  # Component to show a transcript based on normalized OralHistoryContent::Paragraph
  # list!
  #
  # For now does not handle footnotes.
  #
  # May include timestamps and page markers in sidebar if present in Paragraph objects!
  #
  # The VttTranscriptComponent sub-classes this to provide additional func
  # based on an OHMS VTT transcript and it's metadata, including footnotes.
  class ParagraphTranscriptComponent < ApplicationComponent
    delegate :format_ohms_timestamp, to: :helpers

    attr_reader :paragraphs, :base_link

    # @param paragraphs [Array<OralHistoryContent::Paragraph>]
    # param base_link [String] when this will be rendered on a page without the audio player,
    #     base_link helps us link to the page with audio player, for links that should play
    #     at timestamp.
    def initialize(paragraphs, base_link:nil)
      if bad_type = paragraphs.find { |p| ! p.kind_of?(OralHistoryContent::Paragraph)}
        raise ArgumentError.new("paragraphs must be all OralHistoryContent::Paragraph but included #{bad_type.class.name}")
      end

      @paragraphs = paragraphs
      @base_link= base_link
    end

    # THIS IS THE PRIMARY API with template, call and yield timestamp_seconds:, speaker_label:,  html_text:
    #
    # @yieldparam speaker_label
    # @yieldparam html_text
    # @yieldparam start_seconds
    # @yieldparam page_parker eg "1" or "2"
    # @yieldparam fragment_id
    def display_paragraphs
      last_speaker = nil
      last_page_number = nil

      paragraphs.each do |paragraph|
        text, changes = replace_internal_markers(paragraph)

        yield(
          speaker_label: (paragraph.speaker_name if paragraph.speaker_name != last_speaker),
          html_text: text,
          start_seconds: (paragraph.included_timestamps&.first if !changes[:timestamp]),
          page_marker: (paragraph.pdf_logical_page_number if (!changes[:page]) && paragraph.pdf_logical_page_number != last_page_number),
          fragment_id: paragraph.fragment_id
        )

        last_speaker = paragraph.speaker_name
        last_page_number = changes[:page] || paragraph.pdf_logical_page_number
      end
    end

    def render_page_marker(page_marker)
      content_tag("span", "Page #{page_marker}", class: "ohms-transcript-timestamp text-muted")
    end

    def render_timestamp_marker(start_seconds)
      content_tag("a",
                  format_ohms_timestamp(start_seconds),
                  href: "#{base_link}#t=#{start_seconds}",
                  class: "ohms-transcript-timestamp default-link-style",
                    # must be formatted exactly the same in JS transcript highlighter
                    # code that searches for it.
                  data: { "ohms_timestamp_s" => "%.3f" % start_seconds.round(3)}
      )
    end

    # usually a new page or timestamp are just indicated by change in metadata between
    # paragraphs.
    #
    # But sometimes there's an internal marker in the text for EXACTLY where it belongs.
    # In those cases, we need to actually replace the internal marker with proper html safe
    # tag, so the marker shows up corresopnding to correct line.
    #
    # We also need to return IF it was replaced, so we don't double-place it due to
    # changed metadata, and if it was a page marker, what it was, so we can keep track
    # of page changes.
    #
    # And we have to be searching for two at once, and HTML-escaping the data on either
    # side, kind of convoluted.
    def replace_internal_markers(paragraph)
      text = paragraph.text
      orig_html_safe = text.html_safe?

      replaced_page_marker = nil
      replaced_timestamp = nil

      # can match either, we use named capture group so we can figure out
      # which we matched.
      regex = %r{(?:<T: (?<timestamp_m>\d+) min>)|(?:<PAGE-BREAK next=['"](?<break_page>\d+)['"]></PAGE-BREAK>)}

      results = []
      last = 0
      text.scan(regex) do |captures|
        match = Regexp.last_match

        previous = text[last...match.begin(0)]
        previous.html_safe! if orig_html_safe
        results << previous

        if match[:break_page]
          results << render_page_marker(match[:break_page])
          replaced_page_marker = match[:break_page].to_i
        elsif match[:timestamp_m]
          # we don't use the value from <T:>, becuase it hasn't been normalized
          # for multiple files, we just use the value from the paragraph?
          if paragraph.included_timestamps&.first
            results << render_timestamp_marker(paragraph.included_timestamps.first)
            replaced_timestamp = true
          end
        end
        last = match.end(0)
      end
      previous = text[last..]
      previous.html_safe! if orig_html_safe
      results << previous

      # safe_join will html_escape components that aren't html_safe before joining
      return [
        ActionController::Base.helpers.safe_join(results),
        { page: replaced_page_marker, timestamp: replaced_timestamp}
      ]
    end


    # We don't handle this yet, but sub-class does. Should refactor and make more encapsulated
    # when we bump up to here, maybe change name of method even.
    def sanitized_footnotes
      {}
    end
  end
end
