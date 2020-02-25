require 'rails_helper'

describe OhmsTranscriptDisplay, type: :presenter do
  let(:ohms_xml_path) { Rails.root + "spec/test_support/ohms_xml/duarte_OH0344.xml"}
  let(:ohms_xml) { OralHistoryContent::OhmsXml.new(File.read(ohms_xml_path))}
  let(:ohms_transcript_display) { OhmsTranscriptDisplay.new(ohms_xml) }

  let(:transcript_text) { ohms_xml.parsed.at_xpath("//ohms:transcript", ohms: OralHistoryContent::OhmsXml::OHMS_NS).text }

  it "produces good html" do
    # we're just gonna spot check, while by the by ensuring that display does not raise.
    parsed = Nokogiri::HTML.fragment(ohms_transcript_display.display)

    expect(parsed.css("span.ohms-transcript-line").count).to eq(transcript_text.split("\n").count)
    expect(parsed.css("p.ohms-transcript-paragraph").count).to eq(transcript_text.split("\n\n").count)
    # plus one because we have added one for the 0 timestamp
    expect(parsed.css("a.ohms-transcript-timestamp").count).to eq(ohms_xml.sync_timecodes.count + 1)

    first_line = parsed.css("div.ohms-transcript-container > p.ohms-transcript-paragraph > span.ohms-transcript-line").first
    expect(first_line.to_html).to eq(
      %Q{<span class="ohms-transcript-line" id="ohms_line_1"><a href="#" class="ohms-transcript-timestamp" data-ohms-timestamp-s="0">00:00:00</a><span class="ohms-speaker">BROCK:</span> This is an oral history interview with Ron Duarte taking place on 13 June \n</span>}
    )
  end
end
