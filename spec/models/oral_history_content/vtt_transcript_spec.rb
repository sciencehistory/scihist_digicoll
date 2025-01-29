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
    expect(first_cue.start).to eq "00:00:00.000"
    expect(first_cue.start_sec_f).to eq 0.0
    expect(first_cue.end).to eq "00:00:02.000"
    expect(first_cue.end_sec_f).to eq 2.0
    expect(first_cue.paragraphs.length).to eq 1
    expect(first_cue.paragraphs[0].speaker_name).to eq "Esme Johnson"
    expect(first_cue.paragraphs[0].safe_html).to eq "It’s a <i>blue</i> apple tree!"
    expect(first_cue.paragraphs[0].safe_html.html_safe?).to be true

    second_cue = cues[1]
    expect(second_cue.start).to eq "00:00:02.400"
    expect(second_cue.start_sec_f).to eq 2.4
    expect(second_cue.end).to eq "00:00:04.000"
    expect(second_cue.end_sec_f).to eq 4.0

    expect(second_cue.paragraphs.length).to eq 3
    expect(second_cue.paragraphs.collect(&:safe_html)).to eq [
      "This content has some internal line breaks.",
      "Like this is a paragraph two.",
      "And even three."
    ]
    expect(second_cue.paragraphs.collect(&:speaker_name)).to eq ['Mary','Mary','Mary']

    third_cue = cues[2]
    expect(third_cue.paragraphs.length).to eq 2
    expect(third_cue.paragraphs.collect(&:safe_html)).to eq ['Hee!', '<i>laughter</i>']
    expect(third_cue.paragraphs.collect(&:speaker_name)).to eq ['Esme', nil]
    expect(third_cue.paragraphs.collect(&:safe_html).all? {|a| a.html_safe?}).to be true

    fourth_cue = cues[3]
    expect(fourth_cue.paragraphs.length).to eq 2
    expect(fourth_cue.paragraphs.collect(&:safe_html)).to eq ['Why did the chicken cross the road', 'To get to the other side']
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
end
