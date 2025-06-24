require 'rails_helper'

describe OralHistoryContent::OhmsXml::VttTranscript do
  let(:sample_webvtt) do
    # Example includes what OHMS might, but also some extra stuff in WebVTT
    # standard (but not necessarily everything!), to be a bit forward looking.
    <<~EOS
      WEBVTT

      NOTE
      TRANSCRIPTION BEGIN

      00:00:00.000 --> 00:00:02.000 align:left size:50%
      <v.first.loud Esme Johnson>It’s a <i>blue</i> <script>apple</script> tree!

      00:00:02.400 --> 00:00:04.000
      <v Mary>This content has some internal line breaks.
         Like this is a paragraph two.
         And even three.

      00:00:04.400 --> 00:00:06.000
      <v Esme>Hee!</v> <i>laughter</i>

      00:00:06.000 --> 00:00:08.000
      <v Mary>Why did the chicken cross the road</v>
      <v Doug>To get to the other side</v>

      NOTE
      TRANSCRIPTION END

    EOS
  end

  let(:vtt_transcript) { described_class.new(sample_webvtt) }

  it "parses" do
    cues = vtt_transcript.cues

    expect(cues.length).to eq 4

    first_cue = cues[0]
    expect(first_cue.start.to_s).to eq "00:00:00.000"
    expect(first_cue.start_sec_f).to eq 0.0
    expect(first_cue.end.to_s).to eq "00:00:02.000"
    expect(first_cue.end_sec_f).to eq 2.0
    expect(first_cue.paragraphs.length).to eq 1
    expect(first_cue.paragraphs[0].speaker_name).to eq "Esme Johnson"
    expect(first_cue.paragraphs[0].raw_html).to eq "It’s a <i>blue</i> <script>apple</script> tree!"

    second_cue = cues[1]
    expect(second_cue.start.to_s).to eq "00:00:02.400"
    expect(second_cue.start_sec_f).to eq 2.4
    expect(second_cue.end.to_s).to eq "00:00:04.000"
    expect(second_cue.end_sec_f).to eq 4.0

    expect(second_cue.paragraphs.length).to eq 3
    expect(second_cue.paragraphs.collect(&:raw_html)).to eq [
      "This content has some internal line breaks.",
      "Like this is a paragraph two.",
      "And even three."
    ]
    expect(second_cue.paragraphs.collect(&:speaker_name)).to eq ['Mary','Mary','Mary']

    third_cue = cues[2]
    expect(third_cue.paragraphs.length).to eq 2
    expect(third_cue.paragraphs.collect(&:raw_html)).to eq ['Hee!', '<i>laughter</i>']
    expect(third_cue.paragraphs.collect(&:speaker_name)).to eq ['Esme', nil]
    expect(third_cue.paragraphs.collect(&:raw_html)).not_to include( be_html_safe)

    fourth_cue = cues[3]
    expect(fourth_cue.paragraphs.length).to eq 2
    expect(fourth_cue.paragraphs.collect(&:raw_html)).to eq ['Why did the chicken cross the road', 'To get to the other side']
    expect(fourth_cue.paragraphs.collect(&:speaker_name)).to eq ['Mary', 'Doug']
  end

  it "has transcript_text" do
    text = vtt_transcript.transcript_text
    expect(text).to be_present

    expect(text).to include "Esme Johnson: It’s a blue apple tree!"
    expect(text).to include "Why did the chicken cross the road"
  end

  describe "minute-second timecodes" do
    let(:sample_webvtt) do
      # mm:ss.fff timestamps without hh
      <<~EOS
        WEBVTT

        00:00.000 --> 00:02.000 align:left size:50%
        <v.first.loud Esme Johnson>It’s a <i>blue</i> <script>apple</script> tree!

        00:02.400 --> 00:04.000
        <v Mary>This content has some internal line breaks.
           Like this is a paragraph two.
           And even three.

      EOS
    end

    it "still parses" do
      expect(vtt_transcript.cues.length).to eq 2

      expect(vtt_transcript.cues.first.start_sec_f).to eq 0
      expect(vtt_transcript.cues.first.end_sec_f).to eq 2

      expect(vtt_transcript.cues.second.start_sec_f).to eq 2.4
      expect(vtt_transcript.cues.second.end_sec_f).to eq 4
    end
  end

  describe "no newline at end of terminal note" do
    # While I think the spec actually requires it, WebVTT from OHMS doesn't always
    # have a trailing newline after last note
    let(:sample_webvtt) do
      <<~EOS
      WEBVTT

      00:00:04.400 --> 00:00:06.000
      One

      00:00:06.000 --> 00:00:08.000
      Two

      NOTE
      TRANSCRIPTION END
      EOS
    end

    it "parses all cues" do
      expect(vtt_transcript.cues.length).to eq 2
      expect(vtt_transcript.cues.last.text).to eq "Two"
    end
  end

  describe "paragraphs split by br tags ala OHMS" do
    let(:sample_webvtt) do
      <<~EOS
      WEBVTT

      00:00:04.400 --> 00:00:06.000
      Paragraph One<br><br>Paragraph Two

      EOS
    end

    it "splits paragraphs" do
      expect(vtt_transcript.cues.first.paragraphs.length).to eq 2
      expect(vtt_transcript.cues.first.paragraphs.first.raw_html).to eq "Paragraph One"
      expect(vtt_transcript.cues.first.paragraphs.second.raw_html).to eq "Paragraph Two"
    end
  end

  describe "ohms annotation references" do
    let(:sample_webvtt) do
      <<~EOS
      WEBVTT

      00:00:04.400 --> 00:00:06.000
      One

      NOTE
      TRANSCRIPTION END

      NOTE
      ANNOTATIONS BEGIN
      Annotation Set Title: Lorem Ipsum Transcript Annotations
      Annotation Set Creator: Lorem Ipsum Generator
      Annotation Set Date: 1985-10-26

      NOTE
      <annotation ref="1">Lorem ipsum <b>dolor</b> sit <i>amet</i>, consectetur adipiscing elit</annotation>
      <annotation ref="2">Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua</annotation>
      <annotation ref="3">Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. See:<a href="https://en.wikipedia.org/wiki/Lorem_ipsum" target="_blank" rel="noopener">Lorem Ipsum</a></annotation>

      NOTE
      ANNOTATIONS END

      EOS
    end

    it "gets annotations as indexed footnotes" do
      expect(vtt_transcript.footnotes).to be_present
      expect(vtt_transcript.footnotes.length).to eq 3

      expect(vtt_transcript.footnotes.keys).to eq ["1", "2", "3"]

      # strings have not been sanitized and should not be marked html-safe
      expect(vtt_transcript.footnotes.values).not_to include( be_html_safe )

      expect(vtt_transcript.footnotes["1"]).to eq "Lorem ipsum <b>dolor</b> sit <i>amet</i>, consectetur adipiscing elit"
      expect(vtt_transcript.footnotes["2"]).to eq "Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua"
      expect(vtt_transcript.footnotes["3"]).to eq 'Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. See:<a href="https://en.wikipedia.org/wiki/Lorem_ipsum" target="_blank" rel="noopener">Lorem Ipsum</a>'
    end
  end

  describe "file with binary encoding" do
    let(:sample_webvtt) do
      <<~EOS.force_encoding("BINARY")
        WEBVTT

        00:00.000 --> 00:02.000 align:left size:50%
        This has « utf-8 in it »!

      EOS
    end

    it "still ingests as UTF-8" do
      expect(vtt_transcript.cues.first.text).to eq "This has « utf-8 in it »!"
    end
  end

  describe "invalid input" do
    let(:sample_webvtt) { "this\n\nis not it"}

    it "raises in strict mode" do
      expect {
        described_class.new(sample_webvtt, auto_correct_format: false)
      }.to raise_error(WebVTT::MalformedFile)
    end
  end
end
