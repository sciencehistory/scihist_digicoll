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
    attr_reader :errors

    def initialize(xml_str)
      @xml_str = xml_str
    end

    def valid?
      @errors = []

      doc = Nokogiri::XML(@xml_str) { |config| config.strict }

      self.class.xsd.validate(doc).each do |error|
        @errors << "XSD validation error: #{error.message}"
      end

      return @errors.empty?
    rescue Nokogiri::XML::SyntaxError => e
      @errors << "#{e.class}: #{e.message}"
      return false
    end

    # lazy load/parse
    def self.xsd
      @xsd ||= Nokogiri::XML::Schema(File.read(Rails.root + "lib/ohms/ohms.xsd"))
    end
  end
end
