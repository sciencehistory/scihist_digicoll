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
    let(:xml_str) { File.read(Rails.root + "spec/test_support/ohms_xml/hanford_OH0139.xml")}
    it "is valid" do
      foonote_re = /\[\[note\]\].*?\[\[\/note\]\]/m
      xml_str_minus_first_footnote = xml_str.sub(foonote_re, '')
      expect(xml_str.scan(foonote_re).count).to eq 2
      expect(xml_str_minus_first_footnote.scan(foonote_re).count).to eq 1

      expect(validator.valid?).to be(true)
      expect(validator.errors).to be_empty
    end
  end

  describe "reference to a missing footnote" do
    let(:xml_str) { File.read(Rails.root + "spec/test_support/ohms_xml/hanford_OH0139.xml")}
    it "is not valid" do
      foonote_re = /\[\[note\]\].*?\[\[\/note\]\]/m
      xml_str_minus_first_footnote = xml_str.sub(foonote_re, '')
      expect(xml_str.scan(foonote_re).count).to eq 2
      expect(xml_str_minus_first_footnote.scan(foonote_re).count).to eq 1
      val = OralHistoryContent::OhmsXmlValidator
        .new(xml_str_minus_first_footnote)
      expect(val.valid?).to be(false)
      expect(val.errors).to eq ["Reference to missing footnote 2"]
    end
  end

  describe "no footnote section at all, but references present" do
    let(:xml_str) { File.read(Rails.root + "spec/test_support/ohms_xml/hanford_OH0139.xml")}
    it "is not valid" do
      foonotes_re = /\[\[footnotes\]\].*?\[\[\/footnotes\]\]/m
      xml_str_minus_all_footnotes = xml_str.sub(foonotes_re, '')
      expect(xml_str.scan(foonotes_re).count).to eq 1
      expect(xml_str_minus_all_footnotes.scan(foonotes_re).count).to eq 0
      val = OralHistoryContent::OhmsXmlValidator
        .new(xml_str_minus_all_footnotes)
      expect(val.valid?).to be(false)
      expect(val.errors).to eq ["Reference to missing footnote 1", "Reference to missing footnote 2"]
    end
  end

  describe "space next to the number in a footnote reference" do
    let(:xml_str) { File.read(Rails.root + "spec/test_support/ohms_xml/hanford_OH0139.xml")}
    it "is tolerated" do
      foonote_ref_re = %r{\[\[footnote\]\] *(\d+?) *\[\[\/footnote\]\]}
      xml_str_with_spaces_in_footnote = xml_str.sub(foonote_ref_re, '[[footnote]]   2   [[/footnote]]')
      expect(xml_str.scan(foonote_ref_re).count).to eq 2
      expect(xml_str_with_spaces_in_footnote.scan(foonote_ref_re).count).to eq 2
      val = OralHistoryContent::OhmsXmlValidator
        .new(xml_str_with_spaces_in_footnote)
      expect(val.valid?).to be(true)
    end
  end

end
