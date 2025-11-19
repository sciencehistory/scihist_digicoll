require 'rails_helper'

describe OralHistory::LegacyTranscriptComponent, type: :component do
  let(:ohms_xml_path) { Rails.root + "spec/test_support/ohms_xml/legacy/duarte_OH0344.xml"}
  let(:ohms_xml) { OralHistoryContent::OhmsXml.new(File.read(ohms_xml_path))}
  let(:ohms_transcript_display) { OralHistory::LegacyTranscriptComponent.new(ohms_xml.legacy_transcript, transcript_log_id: ohms_xml.accession) }


  let(:ohms_xml_path_with_footnotes) { Rails.root + "spec/test_support/ohms_xml/legacy/hanford_OH0139.xml"}
  let(:ohms_xml_with_footnotes) { OralHistoryContent::OhmsXml.new(File.read(ohms_xml_path_with_footnotes))}
  let(:ohms_transcript_display_with_footnotes) { OralHistory::LegacyTranscriptComponent.new(ohms_xml_with_footnotes.legacy_transcript, transcript_log_id: ohms_xml_with_footnotes.accession) }

  let(:transcript_text) { ohms_xml.parsed.at_xpath("//ohms:transcript", ohms: OralHistoryContent::OhmsXml::OHMS_NS).text }

  it "produces good html" do
    # we're just gonna spot check, while by the by ensuring that display does not raise.
    parsed = render_inline(ohms_transcript_display)

    expect(parsed.css("span.ohms-transcript-line").count).to eq(transcript_text.split("\n").count)
    expect(parsed.css("p.ohms-transcript-paragraph").count).to eq(transcript_text.split("\n\n").count)
    # plus one because we have added one for the 0 timestamp
    expect(parsed.css("a.ohms-transcript-timestamp").count).to eq(ohms_xml.legacy_transcript.sync_timecodes.count + 1)

    first_line = parsed.css("div.ohms-transcript-container p.ohms-transcript-paragraph > span.ohms-transcript-line").first

    expect(first_line.to_html).to eq(
      %Q{<span class="ohms-transcript-line" id="ohms_line_1" data-searchable-transcript-line="true"><a href="#t=0" class="ohms-transcript-timestamp" data-ohms-timestamp-s="0">00:00:00</a><span class="transcript-speaker">BROCK:</span> This is an oral history interview with Ron Duarte taking place on 13 June \n</span>}
    )
  end

  it "properly renders footnotes and references to them" do
    parsed = render_inline(ohms_transcript_display_with_footnotes)
    line_with_first_footnote = parsed.css("#ohms_line_503").to_s

    expect(line_with_first_footnote).to match /Nemours/
    expect(line_with_first_footnote).to include /\"|(&quot;)Polyamides,\"|(&quot;)/
    expect(line_with_first_footnote).to include "[1]"

    expect(parsed.css(".footnote").count).to eq 2
  end

  # Footnotes and footnote references are expected
  # to be well-formed at display time.
  # If there are references to empty or missing footnotes,
  # there should not be a 500 error.
  it "does not raise if footnotes are not available" do
    allow(ohms_xml_with_footnotes.legacy_transcript).to receive(:footnote_array).and_return([])

    render_inline ohms_transcript_display_with_footnotes

    expect(ohms_xml_with_footnotes.legacy_transcript.footnote_array.count).to eq 0
    expect { ohms_transcript_display_with_footnotes.footnote_text_for(1) }.not_to raise_error
    expect { ohms_transcript_display_with_footnotes.footnote_text_for(42) }.not_to raise_error
  end

  it "Correctly handles several footnotes on one line -- and footnotes with spaces around the integer" do
    allow(ohms_xml_with_footnotes.legacy_transcript).
      to receive(:footnote_array).
      and_return(["one", "two", "three"])

    line = OralHistoryContent::OhmsXml::LegacyTranscript::Line.new(
      text: "DUARTE: My grandfather Duarte [[footnote]] 1[[/footnote]] was Portuguese  [[footnote]]2 [[/footnote]] from the Azores  [[footnote]] 3   [[/footnote]] ",
      line_num: 10
    )

    render_inline ohms_transcript_display_with_footnotes

    formatted_line = ohms_transcript_display_with_footnotes.format_ohms_line(line)
    expect(formatted_line).to include "[1]"
    expect(formatted_line).to include "[2]"
    expect(formatted_line).to include "[3]"
  end

  context "Various placements of timecodes" do
    let(:ohms_ns) { "https://www.weareavp.com/nunncenter/ohms" }
    let(:ohms_xml_path) { Rails.root + "spec/test_support/ohms_xml/legacy/various_gaps.xml"}
    let(:parsed) { render_inline(ohms_transcript_display)}

    let(:raw_timecodes) do
      sync = Nokogiri::XML(File.open(ohms_xml_path)).
        at_xpath("//ohms:sync", ohms: ohms_ns).text
      interval_m, stamps = sync.split(":")
      stamps.split("|")
    end

    let(:raw_timecodes_for_lines) do
      raw_timecodes.select do |ts|
        line = ts.split("(")[0].to_i
        line  >= start_line &&
        line  <= end_line
      end.to_a
    end

    let(:processed_timecodes) do
      ohms_transcript_display.sync_timecodes.select do |line, timecodes|
        line >= start_line &&
        line <= end_line
      end
    end

    let(:shown_timecodes) do
      (start_line..end_line).to_a.
        map{ |x| "#ohms_line_#{x} > .ohms-transcript-timestamp" }.
        map{ |selector| parsed.css(selector).text }
    end

    context "line without any timecodes" do
      let(:start_line) { 8 }
      let(:end_line)   { 8 }

      it "doesn't show any." do
        expect(raw_timecodes_for_lines.to_a).to eq []
        expect(processed_timecodes).to eq({})
        expect(shown_timecodes).to eq([""])
      end
    end

    context "first line is blank" do
      let(:start_line) { 1 }
      let(:end_line)   { 3 }

      it "assigns a zero timestamp" do
        allow(ohms_transcript_display).to receive(:sync_timecodes).and_return({})

        render_inline ohms_transcript_display

        expect(
          ohms_transcript_display.format_ohms_line(
            OralHistoryContent::OhmsXml::LegacyTranscript::Line.new(text: "some text", line_num: 1)
          )
        ).to eq("<a href=\"#t=0\" class=\"ohms-transcript-timestamp\" data-ohms-timestamp-s=\"0\">00:00:00</a>some text \n")

        expect(shown_timecodes).to eq(["00:00:00", "", ""])
      end
    end

    context "first word is free, although there are other timecodes on the first line" do
      let(:start_line) { 1 }
      let(:end_line)   { 3 }

      it "assigns a zero timestamp" do
        expect(raw_timecodes_for_lines.to_a).to eq ["1(3)", "3(2)", "3(3)"]
        expect(processed_timecodes).to eq({
            1=>[{:line_number=>"1", :seconds=>60, :word_number=>3}]
        })
        expect(shown_timecodes).to eq( ["00:00:00", "", ""])
      end
    end

    context "already a timestamp on the first word of the first line." do
      let(:start_line) { 1 }
      let(:end_line)   { 3 }

      it "does not assign a zero timestamp " do
        allow(ohms_transcript_display).to receive(:sync_timecodes).and_return(
          { 1=>[{ :seconds=>120, :word_number=>1}] }
        )

        render_inline ohms_transcript_display

        expect(
          ohms_transcript_display.format_ohms_line(
            OralHistoryContent::OhmsXml::LegacyTranscript::Line.new(text: "some text", line_num: 1)
          )
        ).to eq("<a href=\"#t=120\" class=\"ohms-transcript-timestamp\" data-ohms-timestamp-s=\"120\">00:02:00</a>some text \n")
      end
    end

    context "line with two consecutive timestamps" do
      let(:start_line) { 3 }
      let(:end_line)   { 3 }

      it "shows neither" do
        expect(raw_timecodes_for_lines.to_a).to eq ["3(2)", "3(3)"]
        expect(processed_timecodes).to eq({})
        expect(shown_timecodes).to eq( [""])
      end
    end

    context "line with two series of consecutive timecodes" do
      let(:start_line) { 7 }
      let(:end_line)   { 7 }

      it "eliminates both series" do
        expect(raw_timecodes_for_lines.to_a).to eq ["7(2)", "7(3)", "7(8)", "7(9)"]
        expect(processed_timecodes).to eq({})
      end
    end

    context "two nonconsecutive timestamps on the same line" do
      let(:start_line) { 14 }
      let(:end_line)   { 14 }

      it "keeps both, shows the first" do
        expect(raw_timecodes_for_lines.to_a).to eq ["14(1)", "14(3)"]
        expect(processed_timecodes).to eq({14=>[{:line_number=>"14", :seconds=>600, :word_number=>1}, {:line_number=>"14", :seconds=>660, :word_number=>3}]})
        expect(shown_timecodes).to eq(["00:10:00"])
      end
    end

    context "real world example w/ 25 minutes of silence" do
      let(:ohms_xml_path) { Rails.root + "spec/test_support/ohms_xml/legacy/smythe_OH0042.xml"}
      let(:start_line) { 1710 }
      let(:end_line)   { 1725 }

      it "doesn't show the pileup of timestamps" do
        expect(raw_timecodes_for_lines.to_a).to eq(["1710(1)", "1714(3)"] +
          (1..25).map { |x| "1719(#{x})"} + # 25 consecutive timestamps in a row.
          ["1721(1)", "1724(7)"]
        )
        # pp processed_timecodes
        expect(processed_timecodes).to eq({
          1710=>[{:line_number=>"1710", :word_number=>1, :seconds=>15720}],
          1714=>[{:line_number=>"1714", :word_number=>3, :seconds=>15780}],
          1721=>[{:line_number=>"1721", :word_number=>1, :seconds=>17340}],
          1724=>[{:line_number=>"1724", :word_number=>7, :seconds=>17400}]
        })
        expect(shown_timecodes).to eq([
          "04:22:00", "", "", "",
          "04:23:00", "", "", "", "", "", "",
          "04:49:00", "", "",
          "04:50:00", ""
        ])
      end
    end

    context "real world example w/ minute-1 timecode at word 1 and small pileup at line 3" do
      let(:ohms_xml_path) { Rails.root + "spec/test_support/ohms_xml/legacy/smythe_OH0042.xml"}
      let(:start_line) { 1 }
      let(:end_line)   { 5 }

      it "does not add zero timestamp and eliminates pileup" do
        expect(raw_timecodes_for_lines.to_a).to eq(["1(1)", "3(2)", "3(3)", "3(4)"])
        expect(processed_timecodes).to eq(1=>[{:line_number=>"1", :seconds=>60, :word_number=>1}])
        expect(shown_timecodes).to eq(["00:01:00", "", "", "", ""])
      end
    end
  end
end
