require 'rails_helper'

describe WorkAdminHandwritingTranscriptionComponent, type: :component, logged_in_user: :editor do
  let(:feature_flag) { true }
  let(:eligibility_problems) { [] }
  let(:text_extraction_mode) { "handwriting_transcription" }
  let(:request_attributes) { nil }
  let(:work) do
    create(:work,
      text_extraction_mode: text_extraction_mode,
      handwriting_transcription_request: request_attributes
    )
  end

  before do
    allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
    allow(ScihistDigicoll::Env).to receive(:lookup).with(:gemini_htr_transcripts_feature_flag).and_return(feature_flag)

    allow(GeminiHandwritingTranscriptionService).to receive(:new).and_return(
      instance_double(GeminiHandwritingTranscriptionService, work_eligibility_problems: eligibility_problems)
    )
  end

  def new_request_link
    page.find_link("Request a new transcript")
  end

  def delete_link
    page.find_link("Delete transcript")
  end

  describe "with no request yet" do
    it "says one is coming, and offers no buttons" do
      render_inline described_class.new(work)

      expect(page).to have_text("A handwriting transcription will be requested soon.")
      expect(page).not_to have_link("Request a new transcript")
      expect(page).not_to have_link("Delete transcript")
    end

    describe "for an ineligible work" do
      let(:eligibility_problems) { ["no usable images were found"] }

      it "warns that the request will fail" do
        render_inline described_class.new(work)

        expect(page).to have_text("This work isn't eligible for handwriting transcription, because no usable images were found.")
      end
    end
  end

  describe "with a request in progress" do
    let(:request_attributes) do
      {
        status: "requested",
        start_time: Time.zone.parse("2026-01-01 12:30:00"),
        gemini_model: "gemini-test-model",
        source_version: "mock_git_sha"
      }
    end

    it "shows the status, start time and provenance, and offers no buttons" do
      render_inline described_class.new(work)

      expect(page).to have_text("A handwriting transcription is in progress (status: requested).")
      expect(page).to have_text("Started: 2026-Jan-01 12:30")
      expect(page).to have_text("Gemini model: gemini-test-model")
      expect(page).to have_text("Code version: mock_git_sha")
      expect(page).not_to have_link("Go to transcript")
      expect(page).not_to have_link("Request a new transcript")
      expect(page).not_to have_link("Delete transcript")
    end
  end

  describe "with a successful request" do
    let(:request_attributes) { { status: "success" } }

    it "offers to replace the transcript, with a confirmation" do
      render_inline described_class.new(work)

      expect(page).to have_text("A handwriting transcription exists for this work.")
      expect(new_request_link["href"]).to eq("/admin/works/#{work.friendlier_id}/request_new_handwriting_transcription")
      expect(new_request_link["data-method"]).to eq("post")
      expect(new_request_link["data-confirm"]).to match(/delete the current transcript/)
    end

    it "links to the transcript on the public work page" do
      render_inline described_class.new(work)

      expect(page).to have_link("Go to transcript", href: "/works/#{work.friendlier_id}#tab=handwriting-transcription")
    end

    it "offers to delete the transcript, with a confirmation" do
      render_inline described_class.new(work)

      expect(delete_link["href"]).to eq("/admin/works/#{work.friendlier_id}/delete_handwriting_transcription")
      expect(delete_link["data-method"]).to eq("delete")
      expect(delete_link["data-confirm"]).to match(/set the text extraction mode to none/)
    end

    describe "for a work that is no longer eligible" do
      let(:eligibility_problems) { ["no usable images were found"] }

      it "doesn't warn about eligibility" do
        render_inline described_class.new(work)

        expect(page).not_to have_text("isn't eligible")
      end
    end
  end

  describe "with a failed request" do
    let(:request_attributes) { { status: "failure", error: "<b>Gemini</b> returned HTTP 500" } }

    it "shows the escaped error, and offers a new request without a confirmation" do
      render_inline described_class.new(work)

      expect(page).to have_text("The most recent handwriting transcription request failed: <b>Gemini</b> returned HTTP 500")
      expect(page).not_to have_css("b")
      expect(new_request_link["data-confirm"]).to be_nil
      expect(page).not_to have_link("Go to transcript")
    end
  end

  describe "work moved out of handwriting mode, before its transcription has been removed" do
    let(:text_extraction_mode) { "ocr" }
    let(:request_attributes) { { status: "success" } }

    it "offers no buttons, leaving the removal to the background job" do
      render_inline described_class.new(work)

      expect(page).not_to have_link("Delete transcript")
      expect(page).not_to have_link("Request a new transcript")
    end
  end

  describe "work not in handwriting mode, with no request" do
    let(:text_extraction_mode) { "ocr" }

    it "renders nothing" do
      render_inline described_class.new(work)
      expect(page.text).to be_blank
    end
  end

  describe "with the feature flag off" do
    let(:feature_flag) { false }
    let(:request_attributes) { { status: "success" } }

    it "renders nothing" do
      render_inline described_class.new(work)
      expect(page.text).to be_blank
    end
  end

  describe "as a staff viewer, who can't edit works", logged_in_user: :staff_viewer do
    let(:request_attributes) { { status: "success" } }

    it "disables the buttons" do
      render_inline described_class.new(work)

      expect(new_request_link[:class]).to include("disabled")
      expect(delete_link[:class]).to include("disabled")
    end
  end
end
