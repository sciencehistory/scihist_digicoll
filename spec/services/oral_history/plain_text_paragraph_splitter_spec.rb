require 'rails_helper'

describe OralHistory::PlainTextParagraphSplitter do
  let(:raw_transcript_text) { File.read( Rails.root + "spec/test_support/ohms_xml/baltimore_plain_text_transcript_sample.txt")}

  let(:splitter) { described_class.new(plain_text: raw_transcript_text)}
  let(:paragraphs) { splitter.paragraphs }

  it "splits into good paragraphs" do
    expect(paragraphs).to be_present

    # skips prefatory metadata
    expect(paragraphs.first.speaker_name).to eq "SCHLESINGER"
    expect(paragraphs.first.text).to start_with "SCHLESINGER:  Let’s not start at the beginning but"

    # gets the assumed speaker
    expect(paragraphs[5].speaker_name).to eq nil
    expect(paragraphs[5].assumed_speaker_name).to eq "BALTIMORE"
    expect(paragraphs[5].text).to start_with "So I went out there for the summer"

    # skips more metadata
    expect(paragraphs[8].speaker_name).to eq "SCHLESINGER"
    expect(paragraphs[8].text).to eq "SCHLESINGER:  When did you come to MIT as a faculty member?"


    # Does not include back matter, last paragraph is last transcript paragraph
    expect(paragraphs.last.speaker_name).to eq "BALTIMORE"
    expect(paragraphs.last.text).to start_with "BALTIMORE:  No, the new patent was the work of Mark Feinberg and Raul Andino"

    # does not include any double newlines
    expect(paragraphs).to all satisfy { |p| ! (p.text =~ /\n\n/) }

    # no blank ones
    expect(paragraphs).to all satisfy { |p| ! (p.text =~ /\A\s*\Z/) }
  end

  describe "one with intro and single newline separators" do
    let(:raw_transcript_text) { File.read( Rails.root + "spec/test_support/plain_text_transcript/wood_start.txt")}

    it "splits into good-ish paragraphs" do
      # This is a mess, with paragraphs split on page breaks too, but this is what we get, good enough.

      expect(paragraphs[0].speaker_name).to eq "WOOD"
      expect(paragraphs[0].text).to match /\AWOOD: That was a pretty exciting time.*and a nice\Z/m

      expect(paragraphs[1].assumed_speaker_name).to eq "WOOD"
      expect(paragraphs[1].text).to match /guy\. I went down to see him and said.*end of my career\.\Z/m

      expect(paragraphs[2].speaker_name).to eq "BOHNING"
      expect(paragraphs[2].text).to eq "BOHNING: That's all right. We can come back to that later."

      expect(paragraphs[3].speaker_name).to eq "WOOD"
      expect(paragraphs[3].text).to eq "WOOD: In your letter you asked about early grade and high school education and teachers."
    end
  end

  describe "with inline timecodes" do
    let(:raw_transcript_text) { File.read( Rails.root + "spec/test_support/plain_text_transcript/isaacs_j2ntg1k_sample_with_timecodes.txt") }

    it "extracts and assigns timecodes" do
      expect(paragraphs[0].speaker_name).to eq "SCHNEIDER"
      expect(paragraphs[0].text).to start_with "SCHNEIDER:  Okay. So today is Monday, December 11, 2023."
      expect(paragraphs[0].included_timestamps).to eq [5]

      expect(paragraphs[1].speaker_name).to eq "ISAACS"
      expect(paragraphs[1].text).to start_with "ISAACS:  Sure. So yeah, I was born and raised"
      expect(paragraphs[1].included_timestamps).to eq [47]

      expect(paragraphs[2].assumed_speaker_name).to eq "ISAACS"
      expect(paragraphs[2].text).to start_with "And some really fond memories, I would say"
      expect(paragraphs[2].included_timestamps).to eq [127]

      expect(paragraphs[3].speaker_name).to eq "SCHNEIDER"
      expect(paragraphs[3].text).to start_with "SCHNEIDER:  And you mentioned the choir. "
      expect(paragraphs[3].included_timestamps).to eq [187]
    end
  end

end
