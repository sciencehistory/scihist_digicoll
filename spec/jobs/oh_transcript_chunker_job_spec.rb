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

  describe "refresh_extracted_pdf_paragraphs" do
    # give it proper PDF set up that we can create paragraphs from

    let(:transcript_asset) do
      build(:asset_with_faked_file, :pdf,
        published: true, role: "transcript",
        faked_file: File.open(Rails.root + "spec/test_support/pdf/oh/Macfarlane_1982_sample_pages_subbr8.pdf"),
        faked_derivatives: {
          "extracted_pdf_text_json" => build(:stored_uploaded_file, file: Rails.root + "spec/test_support/pdf/oh/Macfarlane_1982_extracted_paragraphs.json")
        }
      )
    end

    let(:work) { build(:oral_history_work, :published, members: [transcript_asset] ) }

    describe "missing extracted_pdf_paragraphs" do
      it "will create extracted_pdf_paragraphs" do
        expect(OralHistoryContent::ParagraphContainer).to receive(:create).with(
          oral_history_content: oral_history_content,
          allow_failure_to_sync: true
        )

        expect(Rails.logger).to receive(:info).with(/needs paragraphs, so creating/)

        described_class.perform_now(oral_history_content, refresh_extracted_pdf_paragraphs: true)
      end
    end

    describe "fresh and valid extracted_pdf_paragraphs" do
      before do
        oral_history_content.extracted_pdf_paragraphs = OralHistoryContent::ParagraphContainer.new(
          pdf_md5: transcript_asset.file_metadata["md5"],
          combined_audio_fingerprint: CombinedAudioDerivativeCreator.new(work).fingerprint
        )
      end

      it "does not replace extracted_pdf_paragraphs" do
        expect(OralHistoryContent::ParagraphContainer).not_to receive(:create).with(
          oral_history_content: oral_history_content,
          allow_failure_to_sync: true
        )

        expect(Rails.logger).not_to receive(:info).with(/needs paragraphs, so creating/)

        described_class.perform_now(oral_history_content, refresh_extracted_pdf_paragraphs: true)
      end
    end

    describe "existing not-fresh extracted_pdf_paragraphs" do
      before do
        oral_history_content.extracted_pdf_paragraphs = OralHistoryContent::ParagraphContainer.new(
          pdf_md5: "bad md5",
          combined_audio_fingerprint: "bad fingerprint",
        )
      end

      it "will create new extracted_pdf_paragraphs" do
        expect(OralHistoryContent::ParagraphContainer).to receive(:create).with(
          oral_history_content: oral_history_content,
          allow_failure_to_sync: true
        )

        expect(Rails.logger).to receive(:info).with(/needs paragraphs, so creating/)

        described_class.perform_now(oral_history_content, refresh_extracted_pdf_paragraphs: true)
      end
    end
  end
end
