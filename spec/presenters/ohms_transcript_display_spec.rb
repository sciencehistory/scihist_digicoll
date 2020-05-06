require 'rails_helper'

describe OhmsTranscriptDisplay, type: :presenter do
  let(:ohms_xml_path) { Rails.root + "spec/test_support/ohms_xml/duarte_OH0344.xml"}
  let(:ohms_xml) { OralHistoryContent::OhmsXml.new(File.read(ohms_xml_path))}
  let(:ohms_transcript_display) { OhmsTranscriptDisplay.new(ohms_xml) }


  let(:ohms_xml_path_with_footnotes) { Rails.root + "spec/test_support/ohms_xml/hanford_OH0139.xml"}
  let(:ohms_xml_with_footnotes) { OralHistoryContent::OhmsXml.new(File.read(ohms_xml_path_with_footnotes))}
  let(:ohms_transcript_display_with_footnotes) { OhmsTranscriptDisplay.new(ohms_xml_with_footnotes) }

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

  it "properly renders footnotes" do
    parsed = Nokogiri::HTML.fragment(ohms_transcript_display_with_footnotes.display)
    line_with_first_footnote = parsed.css("#ohms_line_503").to_s

    expect(line_with_first_footnote).to match /Nemours/
    expect(line_with_first_footnote).to match /quot;Polyamides,&amp;quot;/
    expect(line_with_first_footnote).to match /\[1\]/

    expect(parsed.css(".footnote").count).to eq 2

    f_array = ohms_xml_with_footnotes.footnote_array
    expect(f_array [0]).to eq "William E. Hanford (to E.I. DuPont de Nemours & Co.), \"Polyamides,\" U.S. Patent 2,281,576, issued 5 May 1942."
    expect(f_array [1]).to eq "Howard N. and Lucille L. Sloane, A Pictorial History of American Mining: The adventure and drama of finding and extracting nature's wealth from the earth, from pre-Columbian times to the present (New York: Crown Publishers, Inc., 1970)."

    first_footnote = ohms_transcript_display_with_footnotes.footnote_html(1)
    expect(first_footnote).to match /Nemours/
    expect(first_footnote).to match /quot;Polyamides,&amp;quot;/
    expect(first_footnote).to match /\[1\]/
  end

  # Footnotes and footnote references are expected
  # to be well-formed at display time.
  # If there are references to empty or missing footnotes,
  # there should not be a 500 error.
  it "does not raise if footnotes are not available" do
    allow(ohms_xml_with_footnotes).to receive(:footnote_array).and_return([])
    expect(ohms_xml_with_footnotes.footnote_array.count).to eq 0
    expect { ohms_transcript_display_with_footnotes.footnote_html(1) }.not_to raise_error
    expect { ohms_transcript_display_with_footnotes.footnote_html(42) }.not_to raise_error
  end

end
