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
end
