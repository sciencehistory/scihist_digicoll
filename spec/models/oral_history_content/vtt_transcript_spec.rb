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
    expect(cues.collect(&:paragraphs).flatten).to all(be_kind_of(OralHistoryContent::Paragraph))

    first_cue = cues[0]
    expect(first_cue.start.to_s).to eq "00:00:00.000"
    expect(first_cue.start_sec_f).to eq 0.0
    expect(first_cue.end.to_s).to eq "00:00:02.000"
    expect(first_cue.end_sec_f).to eq 2.0
    expect(first_cue.paragraphs.length).to eq 1
    expect(first_cue.paragraphs[0].speaker_name).to eq "Esme Johnson"
    expect(first_cue.paragraphs[0].scrubbed_ohms_vtt_html).to eq "It’s a <i>blue</i> apple tree!"
    expect(first_cue.paragraphs[0].paragraph_index).to eq 1
    expect(first_cue.paragraphs[0]).to have_attributes(included_timestamps: [0.0])

    second_cue = cues[1]
    expect(second_cue.start.to_s).to eq "00:00:02.400"
    expect(second_cue.start_sec_f).to eq 2.4
    expect(second_cue.end.to_s).to eq "00:00:04.000"
    expect(second_cue.end_sec_f).to eq 4.0
    expect(second_cue.paragraphs.first).to have_attributes(included_timestamps: [2.4])
    expect(second_cue.paragraphs.slice(1..-1)).to all(have_attributes(included_timestamps: nil))


    expect(second_cue.paragraphs.length).to eq 3
    expect(second_cue.paragraphs.collect(&:scrubbed_ohms_vtt_html)).to eq [
      "This content has some internal line breaks.",
      "Like this is a paragraph two.",
      "And even three."
    ]
    expect(second_cue.paragraphs.collect(&:speaker_name)).to eq ['Mary','Mary','Mary']
    expect(second_cue.paragraphs.collect(&:paragraph_index)).to eq [2, 3, 4]

    third_cue = cues[2]
    expect(third_cue.paragraphs.length).to eq 2
    expect(third_cue.paragraphs.collect(&:scrubbed_ohms_vtt_html)).to eq ['Hee!', '<i>laughter</i>']
    expect(third_cue.paragraphs.collect(&:speaker_name)).to eq ['Esme', nil]
    expect(third_cue.paragraphs.collect(&:scrubbed_ohms_vtt_html)).not_to include( be_html_safe)
    expect(third_cue.paragraphs.collect(&:paragraph_index)).to eq [5, 6]
    expect(third_cue.paragraphs.first).to have_attributes(included_timestamps: [4.4])
    expect(third_cue.paragraphs.slice(1..-1)).to all(have_attributes(included_timestamps: nil))


    fourth_cue = cues[3]
    expect(fourth_cue.paragraphs.length).to eq 2
    expect(fourth_cue.paragraphs.collect(&:scrubbed_ohms_vtt_html)).to eq ['Why did the chicken cross the road', 'To get to the other side']
    expect(fourth_cue.paragraphs.collect(&:speaker_name)).to eq ['Mary', 'Doug']
    expect(fourth_cue.paragraphs.collect(&:paragraph_index)).to eq [7, 8]
    expect(fourth_cue.paragraphs.first).to have_attributes(included_timestamps: [6.0])
    expect(fourth_cue.paragraphs.slice(1..-1)).to all(have_attributes(included_timestamps: nil))

  end

  it "has transcript_text" do
    text = vtt_transcript.transcript_text
    expect(text).to be_present

    expect(text).to include "Esme Johnson: It’s a blue apple tree!"
    expect(text).to include "Why did the chicken cross the road"
  end

  describe "assumed speakers" do
    let(:sample_webvtt) do
      # Example includes what OHMS might, but also some extra stuff in WebVTT
      # standard (but not necessarily everything!), to be a bit forward looking.
      <<~EOS
        WEBVTT

        NOTE
        TRANSCRIPTION BEGIN

        00:00:29.000 --> 00:00:39.000
        <v SCHNEIDER>   Burnet. And so I’m curious about your childhood, and to start off, if you could talk a little bit about your parents and what they were like, and maybe a little bit about their backgrounds.

        00:00:39.000 --> 00:01:31.000
        <v CHAPPELEAR>   Well, I was born in 1931 when the [Great] Depression was in the United States. My father [Raymond Dero Stallings] was working as a laborer on the dam for Buchanan Lake. When I was two weeks old, he lost his job, as so many people did. And they packed up everything they owned with me and my older half-brother, ten years older than I, in the sedan and went to my grandmother’s [Serena “Rena” Adams Trainer] house in West Texas [Sonora, Texas]. So that was how we started. There were no jobs. So whenever there was a job opening any place at all in West Texas when I was a baby, my parents would load up and go and go there, and they might work a day or a week or two weeks and then be laid off, and they’d go back to my grandmother’s. And this went on.

        00:01:31.000 --> 00:02:28.000
        At one point when I was still a very small baby, they went to California and tried working there. My uncles of my mother’s—through my mother’s family—would hop freights there in Sonora, [Texas] and go out and try to work on the dams. You . . . Depression was really, really a hard, hard time. My father had a seventh-grade education. My mother [Cora Burleson “Cody” Trainer Nicks Stallings] had quit in the eleventh grade because she didn’t have shoes to wear to school. So they both valued education very, very much. My older brother [Sammie “Sam” Roy Nicks], during those very early years that I can’t remember, checked in and out of the Sonora [Independent] School District in one year, seven times. That’s what looking for a job during those years meant.

        00:02:28.000 --> 00:03:34.000
        At any rate, we ended up—when I was starting school we were in Big Spring, Texas again, and I went to a private school. My birthday being in October, somehow or other, they got the money to send me to private school. I don’t know how, but they did. And so I went first grade all to this private school, and I started second grade there in Big Spring. But from that point on, my father was a salesman, a really good one, and he did various things with insurance and other stuff, and we would move and back and forth. And eventually he went into construction business when I was ten years old. But moving around, I went to a total of about ten different elementary schools, so it was quite different. Fortunately, I am very bright, so I didn’t have any problem making straight A’s except for penmanship. Solid C’s. I liked school very much. It was fun.

        00:08:43.000 --> 00:08:46.000
        <v SCHNEIDER>   And what were some of the things that you did at camp?

        NOTE
        TRANSCRIPTION END
      EOS
    end

    it "are assigned" do
      paragraphs = vtt_transcript.cues.collect(&:paragraphs).flatten

      expect(paragraphs.collect(&:speaker_name)).to eq(
        ["SCHNEIDER", "CHAPPELEAR", nil, nil, "SCHNEIDER"]
      )

      expect(paragraphs.collect(&:assumed_speaker_name)).to eq(
        [nil, nil, "CHAPPELEAR", "CHAPPELEAR", nil]
      )
    end
  end

  describe "unsafe html in transcript" do
    let(:sample_webvtt) do
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
        <v Esme>Hee!</v> <i weird="no">laughter</i>

        NOTE
        TRANSCRIPTION END

      EOS
    end

    it "scrubs output" do
      paragraphs = vtt_transcript.cues.collect(&:paragraphs).flatten

      expect(paragraphs.collect(&:scrubbed_ohms_vtt_html)).to eq([
        "It’s a <i>blue</i> apple tree!", # remove script tags
        "This content has some <b>bold</b> and <i>italics</i>", # keep bold and italic
        "Hee!",
        "<i>laughter</i>" # removes attribute
      ])
    end
  end

  describe "with OHMS vtt footnote references" do
    let(:sample_webvtt) do
      # Example includes what OHMS might, but also some extra stuff in WebVTT
      # standard (but not necessarily everything!), to be a bit forward looking.
      <<~EOS
        WEBVTT

        NOTE
        TRANSCRIPTION BEGIN

        00:00:00.000 --> 00:00:02.000
        <v.first.loud Esme Johnson>We have a <c.1>footnote <b>reference</b> text</c>

        NOTE
        TRANSCRIPTION END
      EOS
    end

    it "replaces with XML-legal tag variation" do
      expect(vtt_transcript.cues.first.paragraphs.first.scrubbed_ohms_vtt_html).to eq(
        %q{We have a <c cref="1">footnote <b>reference</b> text</c>}
      )
    end
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
      expect(vtt_transcript.cues.first.paragraphs.first.scrubbed_ohms_vtt_html).to eq "Paragraph One"
      expect(vtt_transcript.cues.first.paragraphs.second.scrubbed_ohms_vtt_html).to eq "Paragraph Two"

      expect(vtt_transcript.cues.first.paragraphs.collect(&:paragraph_index)).to eq [1, 2]
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
