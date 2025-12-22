require 'rails_helper'

describe OralHistory::PlainTextParagraphSplitter do
  let(:raw_transcript_text) { File.read( Rails.root + "spec/test_support/ohms_xml/baltimore_plain_text_transcript_sample.txt")}
  let(:transcript_id) { "OH0198" }

  let(:splitter) { described_class.new(plain_text: raw_transcript_text, oral_history_id: transcript_id)}
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

  it "all has good fragment_ids" do
    expect(paragraphs).to all satisfy { |p| p.fragment_id =~ /\Aoh-t#{transcript_id}-p\d+/ }
  end
end
