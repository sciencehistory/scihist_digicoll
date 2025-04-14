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

end
