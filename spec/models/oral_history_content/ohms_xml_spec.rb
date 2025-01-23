require 'rails_helper'

describe OralHistoryContent::OhmsXml do
  let(:ohms_xml_path) { Rails.root + "spec/test_support/ohms_xml/legacy/duarte_OH0344.xml"}
  let(:ohms_xml) { OralHistoryContent::OhmsXml.new(File.read(ohms_xml_path))}
  let(:ohms_xml_path_with_footnotes) { Rails.root + "spec/test_support/ohms_xml/legacy/hanford_OH0139.xml"}
  let(:ohms_xml_with_footnotes) { OralHistoryContent::OhmsXml.new(File.read(ohms_xml_path_with_footnotes))}

  describe "#index_points" do
    it "are as expected" do
      expect(ohms_xml.index_points).to be_present
      expect(ohms_xml.index_points.count).to eq(7)

      # spot check one
      expect(ohms_xml.index_points.second.title).to eq("Growing up with Gordon Moore")
      expect(ohms_xml.index_points.second.timestamp).to eq(212)
      expect(ohms_xml.index_points.second.synopsis).to eq("Gordon Moore’s mother Myra. Gordon Moore moving to Redwood City. Getting into trouble with a wagon. Gordon Moore visiting Pescadero. Gordon Moore tinkering. Grammar school. Sequoia High School. Friends. Gordon Moore as a student.")
      expect(ohms_xml.index_points.second.partial_transcript).to eq("BROCK:  That general store was just down the street, not too far from your family’s tavern?\nDUARTE:  Yes.  The general store is called Muzzi’s now.")
      expect(ohms_xml.index_points.second.keywords).to eq(["Azores", "Gordon E. Moore", "Half Moon Bay", "Pescadero", "ranching", "San Mateo", "sheriff", "Walter E. Moore", "whaling", "Williamson family"])
    end

    describe "with hyperlinks" do
      let(:ohms_xml_path) { Rails.root + "spec/test_support/ohms_xml/index_hyperlinks_example.xml" }

      it "get parsed" do
        no_hyperlinks = ohms_xml.index_points.first
        has_hyperlinks = ohms_xml.index_points.second

        expect(no_hyperlinks.hyperlinks).to eq([])

        expect(has_hyperlinks.hyperlinks.collect(&:to_h)).to eq([
          {:href=>"https://digital.sciencehistory.org/works/cf95jc49c", :text=>"Oral history interview with Hubert N. Alyea"},
          {:href=>"https://digital.sciencehistory.org/works/g445cf063", :text=>"Oral history interview with William E. Hanford"},
          {:href=>"https://digital.sciencehistory.org/works/1n79h560c", :text=>"Oral history interview with Malcolm M. Renfrew"}
        ])
      end
    end
  end

  describe OralHistoryContent::OhmsXml::IndexPoint do
    describe "#html_safe_title" do
      let(:xml) do
        <<~EOS
          <point xmlns="https://www.weareavp.com/nunncenter/ohms">
            <time>0</time>
            <title>Title with &lt;i&gt;allowed&lt;/i&gt; and &lt;p&gt;unallowed&lt;/p&gt; tags plus &lt; isolated &gt; internal brackets</title>
            <title_alt></title_alt>
            <partial_transcript>CARUSO: Today is the sixth of May, 2013. I'm David Caruso.</partial_transcript>
            <partial_transcript_alt></partial_transcript_alt>
            <synopsis>Molina reflects on his childhood and education.</synopsis>
            <synopsis_alt></synopsis_alt>
            <keywords>Chemistry sets;Classical music;</keywords><keywords_alt></keywords_alt>
            <subjects></subjects><subjects_alt></subjects_alt>
            <gpspoints><gps></gps><gps_zoom></gps_zoom><gps_text></gps_text><gps_text_alt></gps_text_alt></gpspoints>
            <hyperlinks><hyperlink></hyperlink><hyperlink_text></hyperlink_text><hyperlink_text_alt></hyperlink_text_alt></hyperlinks>
          </point>"
        EOS
      end
      let(:xml_fragment) { Nokogiri::XML.parse(xml).root }
      let(:index_point) { OralHistoryContent::OhmsXml::IndexPoint.new(xml_fragment) }

      it "appropriately respects and strips tags" do
        expect(index_point.title).to eq("Title with <i>allowed</i> and <p>unallowed</p> tags plus < isolated > internal brackets")
        expect(index_point.html_safe_title).to eq("Title with <i>allowed</i> and unallowed tags plus &lt; isolated &gt; internal brackets")
      end
    end
  end
end
