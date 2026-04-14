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
        yield(
          speaker_label: (paragraph.speaker_name if paragraph.speaker_name != last_speaker),
          html_text: paragraph.text,
          start_seconds: paragraph.included_timestamps&.first,
          page_marker: (paragraph.pdf_logical_page_number if paragraph.pdf_logical_page_number != last_page_number),
          fragment_id: paragraph.fragment_id
        )

        last_speaker = paragraph.speaker_name
        last_page_number = paragraph.pdf_logical_page_number
      end
    end

    # We don't handle this yet, but sub-class does. Should refactor and make more encapsulated
    # when we bump up to here, maybe change name of method even.
    def sanitized_footnotes
      {}
    end
  end
end
