require 'rails_helper'

describe OralHistoryContent::OhmsXmlValidator do
  let(:validator) { described_class.new(xml_str) }

  let(:footnote_ref_re) {
    %r{\[\[footnote\]\] *(\d+?) *\[\[\/footnote\]\]}
  }
  let(:footnote_re) {
    /\[\[note\]\].*?\[\[\/note\]\]/m
  }
  let(:footnote_section_re) {
    footnotes_re = /\[\[footnotes\]\].*?\[\[\/footnotes\]\]/m
  }
  let(:hanford_xml) {
    File.read(Rails.root + "spec/test_support/ohms_xml/legacy/hanford_OH0139.xml")
  }

  let(:duarte_xml) {
      File.read(Rails.root + "spec/test_support/ohms_xml/legacy/duarte_OH0344.xml")
  }

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
    let(:xml_str) { duarte_xml }

    it "is valid" do
      expect(validator.valid?).to be(true)
      expect(validator.errors).to be_empty
    end
  end

  describe "missing reference to a footnote" do
    let(:xml_str) { hanford_xml.sub(footnote_ref_re, '') }

    it "is not valid" do
      expect(hanford_xml.scan(footnote_ref_re).count).to eq 2
      expect(xml_str.scan(footnote_ref_re).count).to eq 1
      expect(validator.valid?).to be(false)
      expect(validator.errors).to eq ["Missing reference(s) to footnote(s): 1"]
    end
  end

  describe "reference to a missing footnote" do
    let(:xml_str) { hanford_xml.sub(footnote_re, '') }

    it "is not valid" do
      expect(hanford_xml.scan(footnote_re).count).to eq 2
      expect(xml_str.scan(footnote_re).count).to eq 1
      expect(validator.valid?).to be(false)
      expect(validator.errors).to eq ["Reference to missing footnote 2"]
    end
  end

  describe "no footnote section at all, but references present" do
    let(:xml_str) { hanford_xml.sub(footnote_section_re, '') }

    it "is not valid" do
      expect(hanford_xml.scan(footnote_section_re).count).to eq 1
      expect(xml_str.scan(footnote_section_re).count).to eq 0
      expect(validator.valid?).to be(false)
      expect(validator.errors).to eq ["Reference to missing footnote 1", "Reference to missing footnote 2"]
    end
  end

  describe "spaces next to the number in a footnote reference" do
    let(:xml_str) { hanford_xml.sub(footnote_ref_re, '[[footnote]]   1   [[/footnote]]') }

    it "are tolerated and properly interpreted" do
      expect(hanford_xml.scan(footnote_ref_re).count).to eq 2
      expect(xml_str.scan(footnote_ref_re).count).to eq 2
      expect(validator.valid?).to be(true)
    end
  end

  describe "Footnote section present, but missing closing end tag" do
    let(:unclosed_footnote_section) do
       hanford_xml.
        match(footnote_section_re)[0].
        gsub('[[/footnotes]]', '')
    end
    let(:xml_str) { hanford_xml.sub(footnote_section_re, unclosed_footnote_section) }

    it "is not valid" do
      expect(hanford_xml.scan(footnote_section_re).count).to eq 1
      expect(xml_str.scan(footnote_section_re).count).to eq 0
      expect(validator.valid?).to be(false)
      expect(validator.errors).to eq ["Footnote section is missing closing section."]
    end
  end

  describe "two consecutive opening footnote reference tags" do
    let(:bad_footnote_ref) { "[[footnote]]note 1[[footnote]]" }
    let(:xml_str) { hanford_xml.sub(footnote_ref_re, bad_footnote_ref) }
    it "is not valid" do
      expect(validator.valid?).to be(false)
      expect(validator.errors).to eq ["Mismatched [[footnote]] tag(s) around footnote reference 2."]
    end
  end

  describe "unclosed footnote" do
    let(:bad_notes) { "[[note]]note 1[[/note]] \n [[/note]]unclosed note 2[[/note]] \n [[note]]note 3[[/note]]" }
    let(:xml_str) { hanford_xml.sub(footnote_re, bad_notes) }
    it "is not valid" do
      expect(validator.valid?).to be(false)
      expect(validator.errors).to eq ["Mismatched [[note]] tag(s) around [[note]] 2."]
    end
  end
end
