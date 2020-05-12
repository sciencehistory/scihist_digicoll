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

  it "properly renders footnotes and references to them" do
    parsed = Nokogiri::HTML.fragment(ohms_transcript_display_with_footnotes.display)
    line_with_first_footnote = parsed.css("#ohms_line_503").to_s

    expect(line_with_first_footnote).to match /Nemours/
    expect(line_with_first_footnote).to include "\"Polyamides,\""
    expect(line_with_first_footnote).to include "[1]"

    expect(parsed.css(".footnote").count).to eq 2

    f_array = ohms_xml_with_footnotes.footnote_array
    expect(f_array [0]).to eq "William E. Hanford (to E.I. DuPont de Nemours & Co.), \"Polyamides,\" U.S. Patent 2,281,576, issued 5 May 1942."
    expect(f_array [1]).to eq "Howard N. and Lucille L. Sloane, A Pictorial History of American Mining: The adventure and drama of finding and extracting nature's wealth from the earth, from pre-Columbian times to the present (New York: Crown Publishers, Inc., 1970)."

    # Footnotes themselves are HTML-escaped
    first_footnote = ohms_transcript_display_with_footnotes.footnote_html(1)
    expect(first_footnote).to match /Nemours/
    expect(first_footnote).to include "&quot;Polyamides,&quot;"
    expect(first_footnote).to include "[1]"
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

  it "HTML in footnotes is escaped" do
    bad_chars = [ "The mathematician's \"daughter\" proved that x > 4." ]
    allow(ohms_xml_with_footnotes).to receive(:footnote_array).and_return(bad_chars)
    resulting_footnote = ohms_transcript_display_with_footnotes.footnote_html(1)
    expect(resulting_footnote).to include '1. The mathematician&#39;s &quot;daughter&quot; proved that x &gt; 4.'
  end

  it "Correctly handles several footnotes on one line -- and footnotes with spaces around the integer" do
    allow(ohms_xml_with_footnotes).
      to receive(:footnote_array).
      and_return(["one", "two", "three"])
    line = {
      :text => "DUARTE: My grandfather Duarte [[footnote]] 1[[/footnote]] was Portuguese  [[footnote]]2 [[/footnote]] from the Azores  [[footnote]] 3   [[/footnote]] ",
      :line_num=>10
    }
    formatted_line = ohms_transcript_display_with_footnotes.format_ohms_line(line)
    expect(formatted_line).to include "[1]"
    expect(formatted_line).to include "[2]"
    expect(formatted_line).to include "[3]"
  end

  context "25-minute gap between two consecutive timecodes" do

    let(:ohms_xml_path) { Rails.root + "spec/test_support/ohms_xml/smythe_OH0042.xml"}
    let(:parsed) { Nokogiri::HTML.fragment(ohms_transcript_display.display)}
    let(:timecode_values) { ohms_transcript_display.sync_timecodes.values}
    let(:start_line) { 1710 }
    let(:end_line) {1725}

    it "does not print out excess timecodes" do
      # These lines contain 5 timecodes, with a big gap between the second and third:
      area_around_blank_space = timecode_values.
          select{ |li| li[:line_number] >= start_line && li[:line_number] <= end_line }
      seconds_with_timecodes = area_around_blank_space.
        map { |li| (li[:seconds]) }

      # 17280 seconds - 15780 seconds == 25 minutes
      expect(seconds_with_timecodes).to eq [15720, 15780, 17280, 17340, 17400]

      # Print out the timecodes in each line.
      # Lines with text, but no timecodes show up as blank strings.
      timecodes_for_each_line = (start_line..end_line).to_a.
        map{ |x| "#ohms_line_#{x} > .ohms-transcript-timestamp" }.
        map{ |selector| parsed.css(selector).text }
      # It only prints out the last timecode before the gap,
      # and the first timecode after it.
      expect(timecodes_for_each_line).to eq [
        "04:22:00", "", "", "",
        "04:23:00", "", "", "", "",
        # .. a 25 minute gap is skipped over ...
        "04:48:00", "",
        "04:49:00", "", "",
        "04:50:00", ""
      ]
    end
  end
end