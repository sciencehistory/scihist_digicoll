require 'rails_helper'

describe OralHistoryContent::OhmsXml do
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
