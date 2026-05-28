require 'rails_helper'

describe OhTranscriptChunkerJob, type: :job do
  # Don't actually run the chunker
  let(:mock_chunker) do
    instance_double(OralHistory::TranscriptChunker).tap do |double|
      allow(double).to receive(:create_db_records)
    end
  end

  let (:mock_chunker_class) do
    chunker = instance_double(OralHistory::TranscriptChunker)

    class_double(OralHistory::TranscriptChunker).tap do |klass|
      allow(klass).to receive(:new).and_return(mock_chunker)
    end
  end

  before do
    stub_const("OhTranscriptChunkerJob::CHUNKER_CLASS", mock_chunker_class)
  end

  let(:work) { build(:oral_history_work, :published) }
  let(:oral_history_content) { work.oral_history_content }

  it "calls chunker to create chunks" do
    expect(mock_chunker_class).to receive(:new).and_return(mock_chunker)
    expect(mock_chunker).to receive(:create_db_records)

    described_class.perform_now(oral_history_content)
  end

  describe "only_if_invalid" do
    describe "with no chunks" do
      it "calls chunker" do
        expect(mock_chunker_class).to receive(:new).and_return(mock_chunker)
        expect(mock_chunker).to receive(:create_db_records)

        described_class.perform_now(oral_history_content, only_if_invalid: true)
      end
    end

    describe "with invalid chunks" do
      before do
        oral_history_content.oral_history_chunks << build(:oral_history_chunk)
      end

      it "calls chunker" do
        expect(mock_chunker_class).to receive(:new).and_return(mock_chunker)
        expect(mock_chunker).to receive(:create_db_records)

        described_class.perform_now(oral_history_content, only_if_invalid: true)
      end
    end

    describe "with valid chunks" do
      before do
        # give it a paragraph source
        oral_history_content.searchable_transcript_source = "Paragraph 1\n\nParagraph 2"

        chunk = build(:oral_history_chunk, start_paragraph_number: 1, end_paragraph_number: 2)
        computed_fingerprint = OralHistory::TranscriptChunker.new(oral_history_content: oral_history_content).computed_source_fingerprint
        chunk.other_metadata['source_fingerprint'] = computed_fingerprint

        oral_history_content.oral_history_chunks << chunk

        # Make sure it's valid
        OralHistory::ChunkValidator.new(oral_history_content, check_source_fingerprints: true).validate!
      end

      it "does not call chunker" do
        expect(mock_chunker_class).not_to receive(:new)
        expect(mock_chunker).not_to receive(:create_db_records)

        expect(Rails.logger).to receive(:info).with(/is valid, so not creating chunks/)

        described_class.perform_now(oral_history_content, only_if_invalid: true)
      end
    end
  end
end
