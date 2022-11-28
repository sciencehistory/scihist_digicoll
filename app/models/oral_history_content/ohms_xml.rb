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


    # An array of footnotes, such that [[footnote]]1[[/footnote]]
    # corresponds to footnote_array[0].
    # The raw xml has these footnotes spread out over a
    # bunch of lines, but we try to output sensible whitespace.
    def footnote_array
      @footnote_array ||= begin
        footnotes_re = /\[\[footnotes\]\](.*?)\[\[\/footnotes\]\]/m
        return [] unless notes = transcript_text.scan(footnotes_re)[0]

        one_footnote_re = /\[\[note\]\](.*?)\[\[\/note\]\]/m
        notes[0].scan(one_footnote_re).
          map{ |x| x[0].gsub(/\s+/, ' ').strip }
      end
    end

    # Returns an ordered array of transcript lines
    # Filters the footnotes out. References to the footnotes, however, are kept;
    # these are dealt with in the view component.
    def transcript_lines
      @transcript_lines ||= begin
        text = transcript_text
        text.gsub!(%r{\[\[footnotes\]\].*?\[\[/footnotes\]\]}m, '')
        text.split("\n")
      end
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

    private

    # Returns A hash where:
    #   the key is an OHMS line number.
    #   the value is a hash containing
    #      line_number, word_number and seconds since the beginning of the interview.
    #
    # Iterate over raw_timecodes.
    # Remove all consecutive timecodes on the same line.
    #
    # Note: this can still result in more than one timestamp on each line.
    # The final determination about which one to show is
    # done in method `timecode_for_line` in ohms_transcript_display.rb.
    def parse_sync!
      timecode_hash = raw_timecodes
      # Skip over all lines with 1 or 0 timecodes...
      timecode_hash.select { |key, value| value.length > 1}.each do |k, timecodes|
        # Figure out which timecodes to keep
        word_numbers_to_keep = delete_neighbors(timecodes.map{|x| x[:word_number]})

        if word_numbers_to_keep.empty?
          timecode_hash.delete(k)
        else
          timecode_hash[k] = timecode_hash[k].select do |rt|
            word_numbers_to_keep.include? rt[:word_number]
          end
        end
      end
      timecode_hash
    end

    # Parse the OHMS <sync> element.
    #
    # It looks like: 1:|13(3)|19(14)|27(9)
    #
    # * `1:`      -- 1 minute granularity: each timecode is separated by 60 seconds.
    # * "13(3)"   -- Timecode 1: minute 1 ends at line 13, word 3.
    # * "19(14)"  -- Timecode 2: minute 2 ends at line 19, word 14.
    # * "27(9)"   -- Timecode 3: minute 3 ends at line 27, word 9.
    # * etc.
    # Return a hash. The line number is the key. The value is an array of timecodes,
    # each associating a word on that line (1-indexed) with an offset, in seconds,
    # from the beginning of the combined audio derivative.
    def raw_timecodes
      @raw_timecodes ||= begin
        sync = parsed.at_xpath("//ohms:sync", ohms: OHMS_NS).text
        return {} unless sync.present?
        minutes_between_timecodes, stamps = sync.split(":")
        seconds_between_timnecodes = minutes_between_timecodes.to_i * 60
        result = {}
        stamps.split("|").enum_for(:each_with_index).each do |stamp, index|
          next unless timecode_hash = process_one_timecode(stamp, index, seconds_between_timnecodes)
          line_num = timecode_hash[:line_number]
          (result[line_num.to_i] ||= []) << timecode_hash
        end
        result
      end
    end

    def process_one_timecode(stamp, index, seconds_between_timecodes)
      return nil if stamp.blank?
      stamp =~ /(\d+)\((\d+)\)/
      line_num, word_num = $1, $2
      return nil unless line_num.present? && word_num.present?
      {
        line_number: line_num,
        word_number: word_num.to_i,
        seconds: index * seconds_between_timecodes,
      }
    end

    # Given an array of distinct integers,
    # delete *all* of them with a neighbor.
    # Example: 1, 2, 3, 6, 18
    # 1, 2, 3 are all neighbors, so we return [6, 18].
    def delete_neighbors(ints)
      result = ints.dup
      neighbors = ints.sort.each_cons(2).
        to_a.map {|a, b|  b - a  ==  1}.
        each_with_index do |has_neighbor, i|
        if has_neighbor
          result.delete(ints[i])
          result.delete(ints[i+1])
        end
      end
      result
    end

  end
end
