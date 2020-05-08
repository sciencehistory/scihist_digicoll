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

    FOOTNOTES_RE =     /\[\[footnotes\]\](.*?)\[\[\/footnotes\]\]/m
    ONE_REFERENCE_RE = %r{\[\[footnote\]\] *(\d+?) *\[\[\/footnote\]\]}
    ONE_FOOTNOTE_RE =   /\[\[note\]\](.*?)\[\[\/note\]\]/m

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
        return [] unless notes = text.scan(FOOTNOTES_RE)[0]
        notes[0].scan(ONE_FOOTNOTE_RE).
          map{ |x| x[0].gsub(/\s+/, ' ').strip }
      end
    end

  end
end
