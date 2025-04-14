require 'rails_helper'

describe SequenceOhTimestampsJob, queue: :inline do
  let(:work) do
    create(:oral_history_work, :combined_derivative, num_audio_files: 3).tap do |work|
      work.oral_history_content.input_docx_transcript = create(:stored_uploaded_file, file: File.open(Rails.root + "spec/test_support/oh_docx/sample-oh-timecode-need-sequencing.docx"))
    end
  end

  it "stores sequenced" do
    described_class.perform_now(work)

    expect(work.oral_history_content.output_sequenced_docx_transcript).to be_present
    expect(work.oral_history_content.output_sequenced_docx_transcript.metadata['filename']).to eq("sample-oh-timecode-need-sequencing-seqeuenced.docx")
    expect(work.oral_history_content.output_sequenced_docx_transcript.metadata['mime_type']).to eq("application/vnd.openxmlformats-officedocument.wordprocessingml.document")
  end

  describe "bad file" do
    let(:work) do
      create(:oral_history_work, :combined_derivative).tap do |work|
        work.oral_history_content.input_docx_transcript = create(:stored_uploaded_file, file: File.open(Rails.root + "spec/test_support/images/20x20.png"))
      end
    end

    it "stores error" do
      described_class.perform_now(work)
      expect(expect(work.oral_history_content.output_sequenced_docx_transcript).not_to be_present)
      expect(work.oral_history_content.input_docx_transcript.metadata["SequenceOhTimestamps_InputError"]).to match /transcript_docx_file is bad.*Zip::Error/
    end
  end

  describe "bad metadata" do
    let(:work) do
      create(:oral_history_work, :combined_derivative, num_audio_files: 2).tap do |work|
        work.oral_history_content.input_docx_transcript = create(:stored_uploaded_file, file: File.open(Rails.root + "spec/test_support/oh_docx/sample-oh-timecode-need-sequencing.docx"))
      end
    end

    it "stores error" do
      described_class.perform_now(work)
      expect(expect(work.oral_history_content.output_sequenced_docx_transcript).not_to be_present)
      expect(work.oral_history_content.input_docx_transcript.metadata["SequenceOhTimestamps_InputError"]).to match /file_start_times arg do not match END OF AUDIO markers in transcript. 3 markers in transcript, but 2/
    end
  end
end
