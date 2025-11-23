require 'rails_helper'

describe OralHistory::OhmsLegacyTranscriptChunker do
  let(:ohms_xml_path) { Rails.root + "spec/test_support/ohms_xml/legacy/smythe_OH0042.xml"}
  let(:interviewee_speaker_label) { "SMYTH"}

  #let(:ohms_xml_path) { Rails.root + "spec/test_support/ohms_xml/legacy/duarte_OH0344.xml"}
  #let(:ohms_xml_path) { Rails.root + "spec/test_support/ohms_xml/legacy/hanford_OH0139.xml"}

  let(:legacy_transcript) { OralHistoryContent::OhmsXml::LegacyTranscript.new(Nokogiri::XML(File.read(ohms_xml_path)))}


  let(:chunker) { described_class.new(legacy_transcript, interviewee_names: [interviewee_speaker_label]) }

  def word_count(*strings)
    strings.collect { |s| s.scan(/\w+/).count }.sum
  end

  describe "split_chunks" do
    let(:chunks) { chunker.split_chunks }

    it "creates chunks as arrays of Paragraphs" do
      expect(chunks).to be_kind_of(Array)
      expect(chunks).to be_present

      expect(chunks).to all satisfy { |chunk| chunk.kind_of?(Array) }
      expect(chunks).to all satisfy { |chunk| chunk.present? }
      expect(chunks).to all satisfy { |chunk| chunk.all? {|item| item.kind_of?(OralHistoryContent::OhmsXml::LegacyTranscript::Paragraph) } }
    end

    it "begins with first paragraph" do
      expect(chunks.first.first).to eq legacy_transcript.paragraphs.first
    end

    it "ends with last paragraph" do
      expect(chunks.last.last).to eq legacy_transcript.paragraphs.last
    end

    it "has two paragraphs of overlap in each chunk" do
      0.upto(chunks.length - 2).each do |index|
        first_chunk = chunks[index]
        second_chunk = chunks[index + 1]

        expect(second_chunk.first(2)).to eq (first_chunk.last(2))
      end
    end

    it "all chunks over minimum word count" do
      expect(chunks).to all satisfy { |chunk| word_count(*chunk.collect(&:text)) >= described_class::LOWER_WORD_LIMIT }
    end

    it "all chunks below max word count" do
      # this is not technically invariant, if we have really long paragraphs it might be forced
      # to go over, but it's true in this example.
      expect(chunks).to all satisfy { |chunk| word_count(*chunk.collect(&:text)) <= described_class::UPPER_WORD_LIMIT }
    end

    it "chunks mostly start with questioner" do
      # third paragraph is the first uniquely new one, first two are overlap. We try
      # to make that first unique one be the interviewer, not the interviewee.
      #
      # But it's definitely not invariant, depends on paragraph size, depends on transcript, but
      # we'll say less than 5% -- current example is more like 1%

      interviewee_first_list = chunks.find_all { |chunk| chunk.third.speaker_name == interviewee_speaker_label }

      expect(interviewee_first_list.count.to_f / chunks.length).to be <= 0.05
    end
  end
end
