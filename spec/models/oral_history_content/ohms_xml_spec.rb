require 'rails_helper'

describe OralHistoryContent::OhmsXml do
  describe "#footnote_array" do
    let(:ohms_xml) { OralHistoryContent::OhmsXml.new(File.read(Rails.root + "spec/test_support/ohms_xml/hanford_OH0139.xml"))}

    it "has parsed content" do
      footnotes_array = ohms_xml.footnote_array

      expect(footnotes_array.length).to eq(2)
      expect(footnotes_array[0]).to eq "William E. Hanford (to E.I. DuPont de Nemours & Co.), \"Polyamides,\" U.S. Patent 2,281,576, issued 5 May 1942."
      expect(footnotes_array[1]).to eq "Howard N. and Lucille L. Sloane, A Pictorial History of American Mining: The adventure and drama of finding and extracting nature's wealth from the earth, from pre-Columbian times to the present (New York: Crown Publishers, Inc., 1970)."
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
