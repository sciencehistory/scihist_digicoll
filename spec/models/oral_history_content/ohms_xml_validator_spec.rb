require 'rails_helper'

describe OralHistoryContent::OhmsXmlValidator do
  let(:validator) { OralHistoryContent::OhmsXmlValidator.new(xml_str) }

  describe "ill-formed_xml" do
    let(:xml_str) { "not xml" }

    it "is invalid" do
      expect(validator.valid?).to be(false)
      expect(validator.errors).to be_present
      expect(validator.errors.first).to include("Nokogiri::XML::SyntaxError")
    end
  end

  describe "invalid for schema" do
    let(:xml_str) { "<foo>bar</foo>" }

    it "is invalid" do
      expect(validator.valid?).to be(false)
      expect(validator.errors).to be_present
      expect(validator.errors.first).to include("No matching global declaration available for the validation root")
    end
  end

  describe "valid OHMS xml" do
    let(:xml_str) { File.read(Rails.root + "spec/test_support/ohms_xml/duarte_OH0344.xml")}

    it "is valid" do
      expect(validator.valid?).to be(true)
      expect(validator.errors).to be_empty
    end
  end
end
