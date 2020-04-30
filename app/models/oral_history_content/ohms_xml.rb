class OralHistoryContent
  # Given XML string for an OHMS XML file, provides access to various parts of it,
  # so caller doesn't need to go into the XML itself, and we memoize for efficiency, and
  # sometimes model more conveniently.
  #
  # Normally only used from the OralHistoryContent model class.
  class OhmsXml
    OHMS_NS = "https://www.weareavp.com/nunncenter/ohms"

    # parsed nokogiri object for OHMS xml
    attr_reader :parsed

    def initialize(xml_str)
      @parsed = Nokogiri::XML(xml_str)
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

    # A hash where key is an OHMS line number. Value is a Hash containing
    # :word_number and :seconds .
    #
    # We parse the somewhat mystical OHMS <sync> element to get it.
    #
    # Public mostly so we can test it. :(
    def sync_timecodes
      @sync_timecodes ||= parse_sync!
    end

    # What ohms calls an index is more like a ToC
    def index_points
      @index_entries ||= parsed.xpath("//ohms:index/ohms:point", ohms: OHMS_NS).collect do |index_point|
        IndexPoint.new(index_point)
      end
    end

    def transcript_text
       @transcript_text = parsed.at_xpath("//ohms:transcript", ohms: OHMS_NS).text
    end


    # Convert the footnotes section into an array the presenter can use. It looks like:
    #
    #      [[footnotes]]
    #
    #     [[note]]William E. Hanford (to E.I. DuPont de Nemours &amp; Co.), &quot;Polyamides,&quot; U.S.
    #     Patent 2,281,576, issued 5 May 1942.[[/note]]
    #
    #      [[/footnotes]]
    def footnotes_as_json
      @footnote_array ||= begin
        notes = transcript_text.scan(/\[\[footnotes\]\](.*)\[\[\/footnotes\]\]/m)[0][0]
        return [] unless notes
        note_strings = notes.scan(/\[\[note\]\](.*?)\[\[\/note\]\]/m).
          map{ |x| x[0].gsub(/\s+/, ' ').strip }
        JSON.pretty_generate(note_strings)
      end
    end

    # Returns an ordered array of transcript lines
    # Filters the footnotes out. References to the footnotes, however, are kept;
    # these are dealt with in the presenter.
    def transcript_lines
      @transcript_lines ||= begin
        text = transcript_text
        # take out footnotes section. It looks like:
        #
        #      [[footnotes]]
        #
        #     [[note]]William E. Hanford (to E.I. DuPont de Nemours &amp; Co.), &quot;Polyamides,&quot; U.S.
        #     Patent 2,281,576, issued 5 May 1942.[[/note]]
        #
        #      [[/footnotes]]
        #
        # Use a non-greedy .*? to try and be non-greedy
        # and get a single footnotes block if there are unexpectedly two,
        # instead of going all the way from beginning of one to end of the other.
        #
        # Need regexp multiline mode to match newlines with `.`
        text.gsub!(%r{\[\[footnotes\]\].*?\[\[/footnotes\]\]}m, '')

        text.split("\n")
      end
    end

    # Represents an ohms //index/point element, what ohms calls an index we might
    # really call a Table of Contents. We're not currently using all the elements,
    # only providing access to those we are.
    class IndexPoint

      attr_reader :title, :partial_transcript, :synopsis, :keywords
      # timestamp is in seconds
      attr_reader :timestamp

      def initialize(xml_node)
        @timestamp = xml_node.at_xpath("./ohms:time", ohms: OHMS_NS).text.to_i
        @title = xml_node.at_xpath("./ohms:title", ohms: OHMS_NS)&.text&.strip || "[Missing]"
        @synopsis = xml_node.at_xpath("./ohms:synopsis", ohms: OHMS_NS)&.text&.strip
        @partial_transcript = xml_node.at_xpath("./ohms:partial_transcript", ohms: OHMS_NS)&.text&.strip
        @keywords = xml_node.at_xpath("./ohms:keywords", ohms: OHMS_NS)&.text&.split(";")
      end
    end

    private

    # A hash where key is an OHMS line number. Value is a Hash containing
    # :word_number and :seconds .
    #
    # We parse the somewhat mystical OHMS <sync> element to get it.
    #
    # It looks like: 1:|13(3)|19(14)|27(9)
    #
    # We believe that means:
    # * `1:` -- 1 minute granularity, so each element is separated by one minute.
    # * "13(3)" -- 13 line, 3rd word is 1s timecode (as it's first element and 1s granularity)
    # * "19(14")  -- 19th line 14th word is 2s timecode
    # * Etc.
    #
    # OHMS seems to actually ignore the word position in placing marker, we may too.
    def parse_sync!
      sync = parsed.at_xpath("//ohms:sync", ohms: OHMS_NS).text
      return {} unless sync.present?

      interval_m, stamps = sync.split(":")
      interval_m = interval_m.to_i

      stamps.split("|").enum_for(:each_with_index).collect do |stamp, index|
        next if stamp.blank?

        stamp =~ /(\d+)\((\d+)\)/
        line_num, word_num = $1, $2
        next unless line_num.present? && word_num.present?

        [line_num.to_i, { word_number: word_num.to_i, seconds: index * interval_m * 60, line_number: line_num.to_i }]
      end.compact.to_h
    end
  end
end
