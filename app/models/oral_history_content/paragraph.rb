class OralHistoryContent

  # A model for an Oral History paragraph, used by the Chunker to make chunks.
  #
  # Different classes can create these, depending on what format of transcript they are creating
  # from (OHMS, plain text, etc)  in some cases there may be subsets.
  #
  # Some may create sub-classes specific to their format, but this is a general API for chunkers.
  #
  # Is an AttrJson::Model so we can serialize to JSON easily to store cached derived paragraphs.
  class Paragraph
    include AttrJson::Model

    def self.fragment_id(paragraph_index:)
      "oh-t-p#{paragraph_index}"
    end

    # add multiline to the one from legacy ohms, cause we do have internal newlines sometimes now
    HAS_SPEAKER_REGEX = Regexp.new(
      OralHistoryContent::OhmsXml::LegacyTranscript::OHMS_SPEAKER_LABEL_RE.source,
      OralHistoryContent::OhmsXml::LegacyTranscript::OHMS_SPEAKER_LABEL_RE.options | Regexp::MULTILINE
    )

    # Intended for text from OHMS VTT html-like text
    TextScrubber = Rails::Html::PermitScrubber.new.tap do |scrubber|
      # 'c' is WebVTT 'class' object, which we only expect in the form
      # of c.1, c.12 etc for OHMS annotation references.
      scrubber.tags = ['i', 'b', 'u', 'c']
      scrubber.attributes = ['cref'] # for our weird custom c tag
    end

    FullSanitizer = Rails::HTML5::FullSanitizer.new

    attr_json :transcript_id, :string

    # @return [integer] 1-based index of paragraph in document
    attr_json :paragraph_index, :integer

    # Plain text, will always be present, may be converted from html
    attr_json :text, :string

    # From OHMS VTT text, with limited HTML tags, and footnote references.
    # OHMS non-legal-XML <c.N> tags have been turned into <c ref="N"> tags, and
    # HTML has been scrubbed for only allow-listed tags and attributes.
    #
    # Can be nil, if not coming from new style OHMS
    attr_json :scrubbed_ohms_vtt_html, :string

    # @return [Array<Integer>] list of timestamps (as seconds) included in ths paragraph
    attr_json :included_timestamps, :float, array: true, default: AttrJson::AttributeDefinition::NO_DEFAULT_PROVIDED

    # @return [Integer] timestamp in seconds of the PREVIOUS timestamp to this paragraph,
    #                   to latest the timestamp sure not to miss beginning of paragraph.
    attr_json :previous_timestamp, :float

    # @return [String] when the paragraph has no speaker name internally, we guess/assume
    #    it has the same speaker as previous paragraph. Store such an assumed speaker name
    #    from previous paragraph here.
    attr_json :assumed_speaker_name, :string

    # Can be blank, but page number in PDF from marked pagination (not physical page)
    attr_json :pdf_logical_page_number, :integer

    # OHMS transcript sub-classes get these from OHMS transcript model classes
    attr_json :speaker_name, :string


    # If we are coming from OHMS VTT, we scrub it of any non-permitted HTML, and then
    # strip ALL html to convert it to required plain `text`.
    def self.from_ohms_vtt_html(ohms_vtt_html:, **attributes)
      attributes[:scrubbed_ohms_vtt_html] = scrub_vtt_html(ohms_vtt_html).strip
      attributes[:text] = strip_tags(attributes[:scrubbed_ohms_vtt_html]) unless attributes[:text]

      self.new(**attributes)
    end

    # Requires text:
    def initialize(text:, **attributes)
      super
    end

    # @return [String] to be used as an `id` attribute within an HTML doc, identifying a particular
    #         paragraph.
    def fragment_id
      self.class.fragment_id(paragraph_index: paragraph_index)
    end

    def word_count
      @word_count ||= OralHistoryContent::OhmsXml::LegacyTranscript.word_count(text)
    end

    # If a paragraph does not begin with a `SPEAKER:` label (usually cause same as last
    # one), add it -- for LLM, helpful if every paragraph begins, no assumptions.
    def text_with_forced_speaker_label
      # if text doesn't already start with speaker, and we HAVE a speaker to add,
      # AND the text doesn't start with "[" which is usually used for labels like [END OF TAPE],
      # then add a speaker.
      if text !~ HAS_SPEAKER_REGEX &&
            (speaker_name&.strip.presence || assumed_speaker_name&.strip.presence) && ! text.start_with?("[")
        "#{speaker_name&.strip.presence || assumed_speaker_name&.strip}: #{text}"
      else
        text
      end
    end

    def self.scrub_vtt_html(raw_html)
      # Turn <c.1> tags to XML-legal <c ref='1'> tags with the one in a ref attribute
      str = raw_html.gsub(/<c\.(\d+)/, "<c cref='\\1'")

      # Scrub all but a few tags
      return Loofah.fragment(str).
              scrub!(TextScrubber).
              to_s
    end

    def self.strip_tags(s)
      # for some reason sometimes br's in input, which can end up eating up whitespace
      # and jamming two words together on strip, so we replace first
      FullSanitizer.sanitize( s.gsub("<br>", "\n") )
    end


  end
end
