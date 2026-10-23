require 'rails_helper'

describe HandwritingTranscriptionJob do
  let(:service) { instance_double(GeminiHandwritingTranscriptionService, add_transcription!: nil) }

  before do
    allow(GeminiHandwritingTranscriptionService).to receive(:new).and_return(service)
  end

  describe "work in handwriting_transcription mode" do
    let(:work) { create(:work, text_extraction_mode: "handwriting_transcription") }

    it "requests a transcription" do
      HandwritingTranscriptionJob.perform_now(work)
      expect(service).to have_received(:add_transcription!)
    end
  end

  describe "work no longer in handwriting_transcription mode" do
    let(:work) { create(:work, text_extraction_mode: "ocr") }

    it "does nothing" do
      HandwritingTranscriptionJob.perform_now(work)
      expect(service).not_to have_received(:add_transcription!)
    end
  end
end
