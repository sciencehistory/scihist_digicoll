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
end
