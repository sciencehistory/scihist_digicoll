require 'rails_helper'

describe OhmsIndexDisplay, type: :presenter do
  let(:ohms_xml_path) { Rails.root + "spec/test_support/ohms_xml/duarte_OH0344.xml"}
  let(:ohms_xml) { OralHistoryContent::OhmsXml.new(File.read(ohms_xml_path))}
  let(:ohms_index_display) { OhmsIndexDisplay.new(ohms_xml) }

  it "smoke test" do
    parsed = Nokogiri::HTML.fragment(ohms_index_display.display)

    expect(parsed.css("div.ohms-index-container > .ohms-index-point").count).to eq(ohms_xml.index_points.count)
  end
end
