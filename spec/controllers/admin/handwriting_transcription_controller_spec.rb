require 'rails_helper'

RSpec.describe Admin::HandwritingTranscriptionController, logged_in_user: :editor, type: :controller, queue_adapter: :test do
  let(:feature_flag) { true }
  let(:text_extraction_mode) { "handwriting_transcription" }
  let(:existing_request) { { status: "success" } }
  let(:asset) { create(:asset, handwriting_transcription: "some handwriting", transcription: "by a person") }
  let(:work) do
    create(:public_work,
      members: [asset],
      text_extraction_mode: text_extraction_mode,
      handwriting_transcription_request: existing_request
    )
  end

  let(:redirect_path) { "#{admin_work_path(work)}#tab=nav-ocr" }

  before do
    allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
    allow(ScihistDigicoll::Env).to receive(:lookup).with(:gemini_htr_transcripts_feature_flag).and_return(feature_flag)
  end

  describe "#request_new_transcription" do
    def do_request
      post :request_new_transcription, params: { id: work.friendlier_id }
    end

    shared_examples "refuses" do |message|
      it "changes nothing, and explains why" do
        expect { do_request }.not_to have_enqueued_job(HandwritingTranscriptionJob)

        expect(asset.reload.handwriting_transcription).to eq "some handwriting"
        expect(response).to redirect_to(redirect_path)
        expect(flash[:error]).to match(message)
      end
    end

    describe "after a successful request" do
      it "removes the old transcript, queues a fresh request, and redirects" do
        expect { do_request }.to have_enqueued_job(HandwritingTranscriptionJob).with(work)

        expect(asset.reload.handwriting_transcription).to be_nil
        expect(work.reload.handwriting_transcription_request.status).to eq "queued"
        expect(response).to redirect_to(redirect_path)
        expect(flash[:notice]).to match(/Requested a new transcript/)
      end
    end

    describe "after a failed request" do
      let(:existing_request) { { status: "failure", error: "Gemini was down" } }

      it "queues a fresh request, forgetting the old error" do
        expect { do_request }.to have_enqueued_job(HandwritingTranscriptionJob).with(work)

        request = work.reload.handwriting_transcription_request
        expect(request.status).to eq "queued"
        expect(request.error).to be_nil
      end
    end

    describe "while a request is in progress" do
      let(:existing_request) { { status: "requested" } }
      include_examples "refuses", /still in progress/
    end

    describe "with no request yet" do
      let(:existing_request) { nil }
      include_examples "refuses", /doesn't have a transcription request/
    end

    describe "work not in handwriting_transcription mode" do
      let(:text_extraction_mode) { "ocr" }
      include_examples "refuses", /isn't set to handwriting transcription/
    end

    describe "with the feature flag off" do
      let(:feature_flag) { false }
      include_examples "refuses", /isn't available/
    end
  end

  describe "#delete_transcription" do
    def do_request
      delete :delete_transcription, params: { id: work.friendlier_id }
    end

    it "removes the transcript and the request, sets the mode to none, reindexes, and redirects" do
      expect { do_request }.to have_enqueued_job(ReindexWorksJob).with([work.id])

      expect(asset.reload.handwriting_transcription).to be_nil
      expect(asset.transcription).to eq("by a person")
      work.reload
      expect(work.handwriting_transcription_request).to be_nil
      expect(work.text_extraction_mode).to be_nil

      expect(response).to redirect_to(redirect_path)
      expect(flash[:notice]).to eq("Transcript deleted, and text extraction mode set to none.")
    end

    it "does not lead to a new request" do
      do_request

      WorkOcrCreatorRemover.new(work.reload).process
      expect(HandwritingTranscriptionJob).not_to have_been_enqueued
    end

    describe "while a request is in progress" do
      let(:existing_request) { { status: "queued" } }

      it "still deletes" do
        do_request
        work.reload
        expect(work.handwriting_transcription_request).to be_nil
        expect(work.text_extraction_mode).to be_nil
      end
    end

    describe "when removal fails" do
      before do
        allow_any_instance_of(GeminiHandwritingTranscriptionService)
          .to receive(:remove_transcription!).and_raise(StandardError.new("something broke"))
        allow(Rails.logger).to receive(:error)
      end

      it "changes nothing, acknowledges the error, and logs it" do
        do_request

        expect(work.reload.text_extraction_mode).to eq "handwriting_transcription"
        expect(response).to redirect_to(redirect_path)
        expect(flash[:error]).to eq("We were unable to delete the transcript. Please check the logs for more information.")
        expect(flash[:notice]).to be_nil
        expect(Rails.logger).to have_received(:error).with(/Could not delete handwriting transcript for work #{work.friendlier_id}: StandardError: something broke/)
      end
    end

    describe "with the feature flag off" do
      let(:feature_flag) { false }

      it "changes nothing" do
        do_request

        expect(asset.reload.handwriting_transcription).to eq "some handwriting"
        expect(work.reload.text_extraction_mode).to eq "handwriting_transcription"
        expect(flash[:error]).to match(/isn't available/)
      end
    end
  end

  describe "as a staff viewer, who can't edit works", logged_in_user: :staff_viewer do
    it "refuses to delete" do
      delete :delete_transcription, params: { id: work.friendlier_id }

      expect(asset.reload.handwriting_transcription).to eq "some handwriting"
      expect(work.reload.text_extraction_mode).to eq "handwriting_transcription"
    end

    it "refuses to request a new transcription" do
      expect {
        post :request_new_transcription, params: { id: work.friendlier_id }
      }.not_to have_enqueued_job(HandwritingTranscriptionJob)
    end
  end
end
