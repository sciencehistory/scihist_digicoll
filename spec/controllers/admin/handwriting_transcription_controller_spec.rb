require 'rails_helper'

RSpec.describe Admin::HandwritingTranscriptionController, :logged_in_user, type: :controller, queue_adapter: :test do
  let(:work) { create(:public_work) }

  before do
    allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
  end

  describe "request_handwriting_transcription" do
    describe "with the feature flag on" do
      before do
        allow(ScihistDigicoll::Env)
          .to receive(:lookup)
          .with(:gemini_htr_transcripts_feature_flag)
          .and_return(true)
      end

      it "enqueues the job and redirects back to the nav-ocr tab" do
        expect {
          get :request_handwriting_transcription, params: { work_id: work.friendlier_id }
        }.to have_enqueued_job(HandwritingTranscriptionJob).with(work)

        expect(response).to redirect_to("#{admin_work_path(work)}#tab=nav-ocr")
        expect(flash[:notice]).to match(/Requesting a transcript/)
      end
    end

    describe "with the feature flag off" do
      before do
        allow(ScihistDigicoll::Env)
          .to receive(:lookup)
          .with(:gemini_htr_transcripts_feature_flag)
          .and_return(false)
      end

      it "does not enqueue a job, and redirects back to the nav-ocr tab" do
        expect {
          get :request_handwriting_transcription, params: { work_id: work.friendlier_id }
        }.not_to have_enqueued_job(HandwritingTranscriptionJob)

        expect(response).to redirect_to("#{admin_work_path(work)}#tab=nav-ocr")
        expect(flash[:notice]).to match(/isn't available/)
      end
    end
  end

  describe "delete_handwriting_transcription" do
    let(:asset) { create(:asset, handwriting_transcription: "some handwriting", transcription: "by a person") }
    let(:work) { create(:public_work, members: [asset]) }

    before do
      work.update!(handwriting_transcription_request: Work::HandwritingTranscriptionRequest.new(status: "success"))
    end

    it "removes the transcript, reindexes, and redirects back to the nav-ocr tab with a message" do
      expect {
        delete :delete_handwriting_transcription, params: { work_id: work.friendlier_id }
      }.to have_enqueued_job(ReindexWorksJob).with([work.id])

      expect(asset.reload.handwriting_transcription).to be_nil
      expect(asset.transcription).to eq("by a person")
      expect(work.reload.handwriting_transcription_request).to be_nil

      expect(response).to redirect_to("#{admin_work_path(work)}#tab=nav-ocr")
      expect(flash[:notice]).to eq("Transcript successfully deleted")
    end

    it "acknowledges an error, and logs it" do
      allow_any_instance_of(GeminiHandwritingTranscriptionService)
        .to receive(:remove_transcription!).and_raise(StandardError.new("something broke"))
      allow(Rails.logger).to receive(:error)

      delete :delete_handwriting_transcription, params: { work_id: work.friendlier_id }

      expect(response).to redirect_to("#{admin_work_path(work)}#tab=nav-ocr")
      expect(flash[:error]).to eq("We were unable to delete the transcript. Please check the logs for more information.")
      expect(flash[:notice]).to be_nil
      expect(Rails.logger).to have_received(:error).with(/Could not delete handwriting transcript for work #{work.friendlier_id}: StandardError: something broke/)
    end
  end
end
