require 'rails_helper'

describe OralHistory::TranscriptChunker do
  let(:ohms_xml_path) { Rails.root + "spec/test_support/ohms_xml/legacy/hanford_OH0139.xml"}
  let(:oral_history_content) { work.oral_history_content }
  let(:chunker) { described_class.new(oral_history_content: oral_history_content) }

  def word_count(*strings)
    # use consistent word count algorithm
    OralHistoryContent::OhmsXml::LegacyTranscript.word_count(*strings)
  end

  describe "OHMS Legacy Transcript" do
    let(:work) {
        build(:oral_history_work, :ohms_xml,
          ohms_xml_text: File.read(ohms_xml_path),
          creator: [{ category: "interviewee", value: "Hanford, William E., 1908-1996"},
                    { category: "interviewer", value: "Bohning, James J."}]
        )
      }

    let(:interviewee_speaker_label) { "HANFORD" }
    let(:legacy_transcript) { oral_history_content.ohms_xml.legacy_transcript }

    describe "#split_chunks" do
      let(:chunks) { chunker.split_chunks }

      it "creates chunks as arrays of Paragraphs" do
        expect(chunks).to be_kind_of(Array)
        expect(chunks).to be_present

        expect(chunks).to all satisfy { |chunk| chunk.kind_of?(Array) }
        expect(chunks).to all satisfy { |chunk| chunk.present? }
        expect(chunks).to all satisfy { |chunk| chunk.all? {|item| item.kind_of?(OralHistoryContent::Paragraph) } }
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

          expect(second_chunk.first(1)).to eq (first_chunk.last(1))
        end
      end

      it "all chunks over minimum word count" do
        # except possibly the last one, which just has what's left.
        expect(chunks.slice(0, chunks.length - 1)).to all satisfy { |chunk| word_count(*chunk.collect(&:text)) >= described_class::LOWER_WORD_LIMIT }
      end

      it "all chunks below max word count" do
        # this is not technically invariant, if we have really long paragraphs it might be forced
        # to go over, but it's true in this example.
        expect(chunks).to all satisfy { |chunk| word_count(*chunk.collect(&:text)) <= described_class::UPPER_WORD_LIMIT }
      end

      it "chunks mostly start with questioner" do
        # second paragraph is the first uniquely new one, first one are overlap. We try
        # to make that first unique one be the interviewer, not the interviewee.
        #
        # But it's definitely not invariant, depends on paragraph size, depends on transcript, with
        # the smaller chunks we're using a lot of them wont' end "right", it's okay.

        interviewee_first_list = chunks.find_all { |chunk| chunk.third.speaker_name == interviewee_speaker_label }

        expect(interviewee_first_list.count.to_f / chunks.length).to be <= 0.20
      end
    end

    describe "#build_chunk_record" do
      let(:list_of_paragraphs) { legacy_transcript.paragraphs.slice(7, 5) }

      it "builds good record" do
        record = chunker.build_chunk_record(list_of_paragraphs)

        expect(record).to be_kind_of(OralHistoryChunk)
        expect(record.persisted?).to be false
        expect(record.oral_history_content).to eq oral_history_content

        expect(record.embedding).to be nil

        expect(record.start_paragraph_number).to eq list_of_paragraphs.first.paragraph_index
        expect(record.end_paragraph_number).to eq list_of_paragraphs.last.paragraph_index
        expect(record.text).to eq list_of_paragraphs.collect(&:text).join("\n\n")

        expect(record.speakers).to eq ["HANFORD", "BOHNING"]

        # json standard says hash keys must be string, pg will insist
        list_of_paragraphs.each do |paragraph|
          timestamp_data = record.other_metadata["timestamps"][paragraph.paragraph_index.to_s]
          expect(timestamp_data).to be_present
          expect(timestamp_data["included"]).to eq paragraph.included_timestamps
          expect(timestamp_data["previous"]).to eq paragraph.previous_timestamp
        end
      end

      describe "paragraphs without speaker labels" do
        let(:speaker_label_regexp) { /\A[A-Z]+\:/ }

        let(:list_of_paragraphs) do
          legacy_transcript.paragraphs.slice(326, 4).tap do |list|
            expect(list.first).not_to match speaker_label_regexp
          end
        end

        it "get their assumed speaker labels included" do
          record = chunker.build_chunk_record(list_of_paragraphs)

          expect(record.text).to match speaker_label_regexp
          expect(record.text.split("\n\n")).to all match speaker_label_regexp
        end
      end
    end

    describe "#create_db_records" do
      # duarte is a nice short one (we don't really have it in OHMS, but works for short test)
      let(:ohms_xml_path) { Rails.root + "spec/test_support/ohms_xml/legacy/duarte_OH0344.xml"}

      describe "with mocked OpenAI embeddings" do
        before do
          allow(OralHistoryChunk).to receive(:get_openai_embeddings) { |*args| [OralHistoryChunk::FAKE_EMBEDDING] * args.count }
        end

        it "saves multiple records" do
          chunker.create_db_records

          chunks =  oral_history_content.reload.oral_history_chunks

          expect(chunks).to be_present
          expect(chunks.first.start_paragraph_number).to eq 1
          expect(chunks.last.end_paragraph_number).to eq legacy_transcript.paragraphs.count
        end
      end
    end
  end

  describe "searchable_transcript_source plain text" do
    let(:raw_transcript_text) { File.read( Rails.root + "spec/test_support/ohms_xml/baltimore_plain_text_transcript_sample.txt")}

    let(:work) {
        build(:oral_history_work,
          creator: [{ category: "interviewee", value: "Baltimore, David, 1938-"},
                    { category: "interviewer", value: "Schlesinger, Sondra"}]
        ).tap { |w| w.oral_history_content.searchable_transcript_source = raw_transcript_text }
    }

    let(:interviewee_speaker_label) { "BALTIMORE" }


    describe "#split_chunks" do
      let(:chunks) { chunker.split_chunks }
      let(:splitter) { OralHistory::PlainTextParagraphSplitter.new(plain_text: raw_transcript_text)}

      it "creates chunks as arrays of Paragraphs" do
        expect(chunks).to be_kind_of(Array)
        expect(chunks).to be_present

        expect(chunks).to all satisfy { |chunk| chunk.kind_of?(Array) }
        expect(chunks).to all satisfy { |chunk| chunk.present? }
        expect(chunks).to all satisfy { |chunk| chunk.all? {|item| item.kind_of?(OralHistoryContent::Paragraph) } }
      end

      it "begins with first paragraph" do
        expect(chunks.first.first.text).to eq splitter.paragraphs.first.text
      end

      it "ends with last paragraph" do
        expect(chunks.last.last.text).to eq splitter.paragraphs.last.text
      end

      it "has two paragraphs of overlap in each chunk" do
        0.upto(chunks.length - 2).each do |index|
          first_chunk = chunks[index]
          second_chunk = chunks[index + 1]

          expect(second_chunk.first(1)).to eq (first_chunk.last(1))
        end
      end
    end
  end
end
