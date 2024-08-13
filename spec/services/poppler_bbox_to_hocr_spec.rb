require 'rails_helper'
#require 'equivalent-xml'


describe PopplerBboxToHocr do
  let(:sample_input) { File.read(Rails.root + "spec/test_support/hocr_xml/extract_from_pdf_sample.bbox") }
  let(:sample_output) { File.read(Rails.root + "spec/test_support/hocr_xml/extract_from_pdf_sample.72.hocr") }

  it "translates to expected output" do
    obj = PopplerBboxToHocr.new(sample_input)
    out = obj.transformed_to_hocr

    expect(out).to be_equivalent_to(sample_output).respecting_element_order
  end

  describe "dpi conversion" do
    let(:dpi) { 300 }
    let(:sample_output) { File.read(Rails.root + "spec/test_support/hocr_xml/extract_from_pdf_sample.300.hocr") }

    it "translates to correct dpi pixels" do
      obj = PopplerBboxToHocr.new(sample_input, dpi: dpi)
      out = obj.transformed_to_hocr

      expect(out).to be_equivalent_to(sample_output).respecting_element_order
    end
  end

  describe "additional meta tags" do
    let(:meta_tags) do
      {
         "Command-line" => "pdftotext something",
         "Pdftotext-version" => "pdftotext version 24.04.0",
         "Process" => "via extracted digital PDF text"
      }
    end

    it "are added" do
      obj = PopplerBboxToHocr.new(sample_input, meta_tags: meta_tags)
      out = obj.transformed_to_hocr_nokogiri
      out.remove_namespaces!

      meta_tags.each do |name, content|
        expect(out.at_xpath("//meta[@name='#{name}'][@content='#{content}']")).to be_present, "<meta name='#{name}' content='#{content}'>"
      end
    end
  end
end
