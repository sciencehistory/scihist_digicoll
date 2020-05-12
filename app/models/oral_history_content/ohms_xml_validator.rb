class OralHistoryContent


  # just makes sure a string is well-formed XML that validates against our the XSD that's
  # mentioned in the OHMS XML export's xsi:schemaLocation at:
  # https://www.weareavp.com/nunncenter/ohms/ohms.xsd
  #
  # (It's a pretty bare-bones XSD)
  #
  #   validator = OhmxXmlValidator.new(string)
  #   validator.valid?
  #   # if not then
  #   validator.errors # => array of strings
  class OhmsXmlValidator
    OHMS_NS = "https://www.weareavp.com/nunncenter/ohms"

    FOOTNOTES_OPENING_RE =    /\[\[footnotes\]\]/
    FOOTNOTES_CLOSING_RE =    /\[\[\/footnotes\]\]/
    FOOTNOTE_REF_OPENING_RE = /\[\[footnote\]\]/
    FOOTNOTE_REF_CLOSING_RE = /\[\[\/footnote\]\]/
    FOOTNOTE_OPENING_RE =     /\[\[note\]\]/
    FOOTNOTE_CLOSING_RE =     /\[\[\/note\]\]/

    FOOTNOTES_SECTION_RE =    /\[\[footnotes\]\](.*?)\[\[\/footnotes\]\]/m
    ONE_FOOTNOTE_RE =         /\[\[note\]\](.*?)\[\[\/note\]\]/m
    ONE_REFERENCE_RE =        /\[\[footnote\]\] *(\d+?) *\[\[\/footnote\]\]/

    attr_reader :errors

    def initialize(xml_str)
      @xml_str = xml_str
    end

    def valid?
      @errors = []

      @doc = Nokogiri::XML(@xml_str) { |config| config.strict }

      self.class.xsd.validate(@doc).each do |error|
        @errors << "XSD validation error: #{error.message}"
      end
      @errors = @errors + footnote_errors
      return @errors.empty?
    rescue Nokogiri::XML::SyntaxError => e
      @errors << "#{e.class}: #{e.message}"
      return false
    end

    def footnote_errors
      # General tests before we check the mapping between references and footnotes:
      if text.match(FOOTNOTES_OPENING_RE).present?
        unless text.match(FOOTNOTES_CLOSING_RE).present?
          return ['Footnote section is missing closing section.']
        end
      end

      tag_pairs = {}
      tag_pairs[:references] = [FOOTNOTE_REF_OPENING_RE, FOOTNOTE_REF_CLOSING_RE]
      tag_pairs[:notes] = [FOOTNOTE_OPENING_RE, FOOTNOTE_CLOSING_RE]

      if (err = error_in_matching_tags(:references))
        return ["Mismatched [[footnote]] tag(s) around footnote reference #{err + 1}."]
      end
      if (err = error_in_matching_tags(:notes))
        return ["Mismatched [[note]] tag(s) around [[note]] #{err + 1}."]
      end
      result = []
      referenced_footnotes = Set.new

      # For each footnote reference
      text.scan(ONE_REFERENCE_RE).each do |f_match|
        footnote_reference_number = f_match[0].to_i
        referenced_footnotes << footnote_reference_number
        # make sure its footnote exists
        if footnote_array[footnote_reference_number - 1] == nil
          result << "Reference to missing footnote #{footnote_reference_number}"
        end
      end

      # and make sure each footnote has at least one reference to it
      unreferenced_footnote_list = (1..footnote_array.count).to_set - referenced_footnotes
      if unreferenced_footnote_list.count > 0
        result << "Missing reference(s) to footnote(s): #{unreferenced_footnote_list.to_a.join(',')}"
      end

      result
    end

    # lazy load/parse
    def self.xsd
      @xsd ||= Nokogiri::XML::Schema(File.read(Rails.root + "lib/ohms/ohms.xsd"))
    end

    def text
      @text ||= begin
        transcript = @doc.at_xpath("//ohms:transcript", ohms: OHMS_NS)
        transcript ? transcript.text : ''
      end
    end

    def footnote_array
      @footnote_array ||= begin
        return [] unless notes = text.scan(FOOTNOTES_SECTION_RE)[0]
        notes[0].scan(ONE_FOOTNOTE_RE).
          map{ |x| x[0].gsub(/\s+/, ' ').strip }
      end
    end

    # Make sure each [[footnote]] and [[note]] tag
    # can be matched up with its corresponding closing tag.
    # This falls short of a full parser, of course,
    # but that's likely overkill.
    def error_in_matching_tags(tag_type)
      tag_pairs = {
        references: [
          FOOTNOTE_REF_OPENING_RE,
          FOOTNOTE_REF_CLOSING_RE
        ],
        notes: [
          FOOTNOTE_OPENING_RE,
          FOOTNOTE_CLOSING_RE
        ]
      }

      opening_tag, closing_tag =  tag_pairs[tag_type]

      text.split(opening_tag).each_with_index do |x, i|
        # Split the string by opening tags
        number_of_closing_tags = x.scan(closing_tag).length

        # The first chunk, before the first opening tag, should have
        # zero closing tags.
        stray_closing_tag_before_first_opening_tag =
          (i == 0 && number_of_closing_tags != 0)
        # All other chunks should contain exactly one closing tag.
        stray_or_missing_closing_tag_after_opening_tag =
          (i >  0 && number_of_closing_tags != 1)

        # Return the index of the chunk that failed the test:
        if stray_closing_tag_before_first_opening_tag ||
          stray_or_missing_closing_tag_after_opening_tag
          return i
        end
      end

      # Great, no errors:
      return nil
    end

  end
end
