require 'rails_helper'

describe OralHistory::VttTranscriptComponent, type: :component do
  let(:ohms_xml_path) { Rails.root + "spec/test_support/ohms_xml/small-sample-vtt-ohms.xml"}
  let(:ohms_webvtt) { Nokogiri::XML(File.read ohms_xml_path).at_css("vtt_transcript").text }
  let(:vtt_transcript) { OralHistoryContent::OhmsXml::VttTranscript.new(ohms_webvtt)}
  let(:vtt_transcript_component) { described_class.new(vtt_transcript) }

  it "renders html as expected" do
    parsed = render_inline(vtt_transcript_component)

    paragraphs = parsed.css(".ohms-transcript-container p.ohms-transcript-paragraph")
    expect(paragraphs.length).to eq 8

    # Don't use same speaker name in multiple paragraphs in a row
    expect(paragraphs.collect { |p| p.css("span.transcript-speaker")&.text }).to eq [
      "SCHNEIDER", "NAME OF INTERVIEWEE", "SCHNEIDER", "NAME OF INTERVIEWEE", "", "", "SCHNEIDER", "NAME OF INTERVIEWEE"
    ]

    # Use timecode links where we got em
    expect( paragraphs.collect { |p| p.at_css("a.ohms-transcript-timestamp")&.text } ).to eq [
      "01:00:03", "01:00:18", "01:00:31", "01:00:38", nil, nil, "01:01:14", "01:01:22"
    ]

    expect(paragraphs.collect { |p| p.at_css("a.ohms-transcript-timestamp").try(:[], 'data-ohms-timestamp-s') }).to eq [
      "3603.000", "3618.000", "3631.000", "3638.000", nil, nil, "3674.000", "3682.000"
    ]
  end

  describe "unsafe html in text" do
    let(:ohms_webvtt) do
      # Example includes what OHMS might, but also some extra stuff in WebVTT
      # standard (but not necessarily everything!), to be a bit forward looking.
      <<~EOS
        WEBVTT

        NOTE
        TRANSCRIPTION BEGIN

        00:00:00.000 --> 00:00:02.000
        <v.first.loud Esme Johnson>It’s a <i>blue</i> <script>apple</script> tree!

        00:00:02.400 --> 00:00:04.000
        <v Mary>This content has some <b>bold</b> and <i>italics</i>

        00:00:04.400 --> 00:00:06.000
        <v Esme>Hee!</v> <i>laughter</i>

        NOTE
        TRANSCRIPTION END

      EOS
    end

    it "scrubs output" do
      parsed = render_inline(vtt_transcript_component)

      paragraphs = parsed.css(".ohms-transcript-container p.ohms-transcript-paragraph")

      expect(paragraphs.length).to eq 4

      expect(paragraphs[0].inner_html).to include "It’s a <i>blue</i> apple tree!" # no more script tag
      expect(paragraphs[1].inner_html).to include "This content has some <b>bold</b> and <i>italics</i>"

      expect(paragraphs[3].inner_html).to include "<i>laughter</i>"
    end
  end

  describe "with annotations" do
    let(:ohms_webvtt) do
      # Example includes what OHMS might, but also some extra stuff in WebVTT
      # standard (but not necessarily everything!), to be a bit forward looking.
      <<~EOS
        WEBVTT

        NOTE
        TRANSCRIPTION BEGIN

        00:00:00.000 --> 00:00:02.000
        <v.first.loud Esme Johnson>We have a <c.1>footnote <b>ref</b> <script>no script tag</script></c>

        NOTE
        TRANSCRIPTION END

        NOTE
        ANNOTATIONS BEGIN
        Annotation Set Title: Lorem Ipsum Transcript Annotations
        Annotation Set Creator: Lorem Ipsum Generator
        Annotation Set Date: 1985-10-26

        NOTE
        <annotation ref="1">Lorem ipsum <b>dolor</b> sit <i>amet</i>, consectetur <script>no script tag</script> <a href="https://example.com">internal link</a></annotation>

        NOTE
        ANNOTATIONS END

      EOS
    end

    it "replaces WebVTT <c.1> classes with our footnote references, html-safely" do
      parsed = render_inline vtt_transcript_component

      footnote_link = parsed.at_css("a.footnote")

      expect(footnote_link).to be_present
      expect(footnote_link.inner_html.strip).to eq "footnote <b>ref</b> no script tag [1]"

      # Nokogiri unescapes for us
      expect(footnote_link['data-bs-content']).to eq (
        'Lorem ipsum <b>dolor</b> sit <i>amet</i>, consectetur no script tag <a href="https://example.com" target="_blank" rel="noopener">internal link</a>'
      )
      expect(footnote_link['data-bs-html']).to eq "true"
    end

    it "renders footnotes at the bottom" do
      parsed = render_inline vtt_transcript_component

      footnotes = parsed.css(".footnote-list .footnote-page-bottom-container")

      expect(footnotes.length).to eq 1
      expect(footnotes.first.inner_html.strip.gsub(/\s+/, ' ')).to eq(
        <<~EOS.gsub(/\s+/, ' ').strip
          <a id="footnote-1" data-role="ohms-navbar-aware-internal-link" href="#footnote-reference-1"> 1.</a>
          <span id="footnote-text-1">Lorem ipsum <b>dolor</b> sit <i>amet</i>,
            consectetur no script tag <a href="https://example.com" target="_blank" rel="noopener">internal link</a></span>
        EOS
      )
    end
  end

  describe "with base_link" do
    let(:vtt_transcript_component) { described_class.new(vtt_transcript, base_link: "/foo/bar") }

    it "includes in link" do
      parsed = render_inline(vtt_transcript_component)

      expect(
        parsed.at_css("a.ohms-transcript-timestamp[href^='/foo/bar#t=']")
      ).to be_present
    end
  end
end
