require 'rails_helper'

describe OralHistory::OhmsIndexComponent, type: :component do
  let(:work) { create(:oral_history_work)}
  let(:ohms_xml_path) { Rails.root + "spec/test_support/ohms_xml/duarte_OH0344.xml"}
  let(:ohms_xml) { OralHistoryContent::OhmsXml.new(File.read(ohms_xml_path))}
  let(:ohms_index_display) { OralHistory::OhmsIndexComponent.new(ohms_xml, work: work) }
  let(:parsed) { render_inline ohms_index_display}

  it "smoke test" do
    expect(parsed.css("div.ohms-index-container > .ohms-index-point").count).to eq(ohms_xml.index_points.count)
  end

  describe "index with hyperlinks" do
    let(:ohms_xml_path) { Rails.root + "spec/test_support/ohms_xml/index_hyperlinks_example.xml"}

    it "renders" do
      expect(parsed.css(".ohms-index-point").count).to eq(2)

      with_hyperlinks = parsed.at_css(".ohms-index-point[2]")
      hyperlinks = with_hyperlinks.css(".ohms-hyperlinks a")

      expect(hyperlinks.count).to eq(3)
      expect(hyperlinks.all? { |h| h["href"].present? && h.text.strip.present? }).to be(true)
    end
  end
end
