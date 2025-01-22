class OralHistoryContent
  # Given XML string for an OHMS XML file, provides access to various parts of it,
  # so caller doesn't need to go into the XML itself, and we memoize for efficiency, and
  # sometimes model more conveniently.
  #
  # Normally only used from the OralHistoryContent model class.
  class OhmsXml
    OHMS_NS = "https://www.weareavp.com/nunncenter/ohms"

    # parsed nokogiri object for OHMS xml
    attr_reader :parsed, :legacy_transcript

    def initialize(xml_str)
      @parsed = Nokogiri::XML(xml_str)
      @legacy_transcript = ::OralHistoryContent::OhmsXml::LegacyTranscript.new(@parsed)
    end

    def record_dt
      @record_at ||= parsed.at_xpath("//ohms:record", ohms: OHMS_NS)["dt"]
    end

    def record_id
      @record_id ||= parsed.at_xpath("//ohms:record", ohms: OHMS_NS)["id"]
    end

    def accession
      @accession ||= parsed.at_xpath("//ohms:record/ohms:accession", ohms: OHMS_NS).text
    end

    # What ohms calls an index is more like a ToC
    def index_points
      @index_entries ||= parsed.xpath("//ohms:index/ohms:point", ohms: OHMS_NS).collect do |index_point|
        IndexPoint.new(index_point)
      end
    end

    def transcript_text
      @legacy_transcript.transcript_text
    end


    # Represents an ohms //index/point element, what ohms calls an index we might
    # really call a Table of Contents. We're not currently using all the elements,
    # only providing access to those we are.
    class IndexPoint

      attr_reader :title, :partial_transcript, :synopsis, :keywords, :subjects
      # timestamp is in seconds
      attr_reader :timestamp

      # has data objects with href and text methods.
      attr_reader :hyperlinks

      def initialize(xml_node)
        @timestamp = xml_node.at_xpath("./ohms:time", ohms: OHMS_NS).text.to_i
        @title = xml_node.at_xpath("./ohms:title", ohms: OHMS_NS)&.text&.strip || "[Missing]"
        @synopsis = xml_node.at_xpath("./ohms:synopsis", ohms: OHMS_NS)&.text&.strip
        @partial_transcript = xml_node.at_xpath("./ohms:partial_transcript", ohms: OHMS_NS)&.text&.strip
        @keywords = xml_node.at_xpath("./ohms:keywords", ohms: OHMS_NS)&.text&.split(";")
        @subjects = xml_node.at_xpath("./ohms:subjects", ohms: OHMS_NS)&.text&.split(";")

        @hyperlinks = xml_node.xpath("./ohms:hyperlinks", ohms: OHMS_NS).collect do |hyperlink_xml|
          href = hyperlink_xml.at_xpath("./ohms:hyperlink", ohms: OHMS_NS)&.text&.strip&.presence
          text = hyperlink_xml.at_xpath("./ohms:hyperlink_text", ohms: OHMS_NS)&.text&.strip&.presence

          if href && text
            OpenStruct.new(
              href: href,
              text: text
            )
          end
        end.compact
      end

      # We generally combine keywords and subjects in the UI into one field.
      def all_keywords_and_subjects
        keywords + subjects
      end

      # We want to allow <i> tags, and strip/escape the rest appropriately.
      def html_safe_title
        Rails::Html::SafeListSanitizer.new.sanitize(title, tags: ['i']).html_safe
      end

    end
  end
end
