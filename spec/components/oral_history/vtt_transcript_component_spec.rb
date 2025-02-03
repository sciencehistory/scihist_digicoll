require 'rails_helper'

describe OralHistory::VttTranscriptComponent, type: :component do
  let(:ohms_xml_path) { Rails.root + "spec/test_support/ohms_xml/small-sample-vtt-ohms.xml"}
  let(:ohms_webvtt) { Nokogiri::XML(File.read ohms_xml_path).at_css("vtt_transcript").text }
  let(:vtt_transcript) { OralHistoryContent::OhmsXml::VttTranscript.new(ohms_webvtt)}
  let(:vtt_transcript_component) { described_class.new(vtt_transcript) }

  it "renders html as expected" do
    parsed = render_inline(vtt_transcript_component)

    paragraphs = parsed.css(".ohms-transcript-container p.ohms-transcript-paragraph.ohms-transcript-line")
    expect(paragraphs.length).to eq 8

    # Don't use same speaker name in multiple paragraphs in a row
    expect(paragraphs.collect { |p| p.css("span.ohms-speaker")&.text }).to eq [
      "SCHNEIDER", "NAME OF INTERVIEWEE", "SCHNEIDER", "NAME OF INTERVIEWEE", "", "", "SCHNEIDER", "NAME OF INTERVIEWEE"
    ]

    # Use timecode links where we got em
    expect( paragraphs.collect { |p| p.at_css("a.ohms-transcript-timestamp")&.text } ).to eq [
      "01:00:03", "01:00:18", "01:00:31", "01:00:38", nil, nil, "01:01:14", "01:01:22"
    ]

    expect(paragraphs.collect { |p| p.at_css("a.ohms-transcript-timestamp").try(:[], 'data-ohms-timestamp-s') }).to eq [
      "3603.0", "3618.0", "3631.0", "3638.0", nil, nil, "3674.0", "3682.0"
    ]
  end
end
