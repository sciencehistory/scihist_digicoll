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
      errors = []
      text_lines = text.split("\n")
      text_lines_with_footnotes =  text_lines.select{ |l| l.include?('[[footnote]]') }
      text_lines_with_footnotes.each do |line|
        footnote_re = %r{\[\[footnote\]\] *(\d+?) *\[\[\/footnote\]\]}
        line.scan(footnote_re).each do |f_match|
          footnote_reference_number = f_match[0].to_i
          if footnote_array[footnote_reference_number - 1] == nil
            errors << "Reference to missing footnote #{footnote_reference_number}"
          end
        end
      end
      errors
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
        footnotes_re = /\[\[footnotes\]\](.*)\[\[\/footnotes\]\]/m
        return [] unless notes = text.scan(footnotes_re)[0]
        one_footnote_re = /\[\[note\]\](.*?)\[\[\/note\]\]/m
          notes[0].scan(one_footnote_re).
          map{ |x| x[0].gsub(/\s+/, ' ').strip }
      end
    end

  end
end
