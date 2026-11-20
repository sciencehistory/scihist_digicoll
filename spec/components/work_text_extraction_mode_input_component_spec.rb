require 'rails_helper'

describe WorkTextExtractionModeInputComponent, type: :component do
  let(:feature_flag) { true }
  let(:eligibility_problems) { [] }
  let(:work) { create(:work) }

  before do
    allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
    allow(ScihistDigicoll::Env).to receive(:lookup).with(:gemini_htr_transcripts_feature_flag).and_return(feature_flag)

    allow(GeminiHandwritingTranscriptionService).to receive(:new).and_return(
      instance_double(GeminiHandwritingTranscriptionService, work_eligibility_problems: eligibility_problems)
    )
  end

  def render_component(form_object = work)
    render_in_view_context(form_object) do |form_object|
      simple_form_for(form_object, as: :work, url: "/admin/works/fake") do |f|
        render WorkTextExtractionModeInputComponent.new(form: f)
      end
    end
  end

  def option_values
    page.all("input[type=radio][name='work[text_extraction_mode]']").map(&:value)
  end

  describe "eligible work" do
    it "offers handwriting transcription, with no warning" do
      render_component
      expect(option_values).to eq ["", "ocr", "pdf_extraction", "handwriting_transcription"]
      expect(page).not_to have_text("We don't recommend")
    end
  end

  describe "ineligible work" do
    let(:eligibility_problems) { ["no usable images were found"] }

    it "still offers handwriting transcription, but warns against it" do
      render_component
      expect(option_values).to include("handwriting_transcription")
      expect(page).to have_text(
        "We don't recommend requesting a handwriting transcription for this work, because no usable images were found."
      )
    end

    describe "that has already had a request" do
      let(:work) do
        create(:work,
          text_extraction_mode: "handwriting_transcription",
          handwriting_transcription_request: { status: "failure", error: "We will not send Work to be transcribed" }
        )
      end

      it "shows the request status instead of the warning" do
        render_component
        expect(page).to have_text("The most recent handwriting transcription request failed: We will not send Work to be transcribed")
        expect(page).not_to have_text("We don't recommend")
      end
    end
  end

  describe "feature flag off" do
    let(:feature_flag) { false }

    it "does not offer handwriting transcription or show messages" do
      render_component
      expect(option_values).to eq ["", "ocr", "pdf_extraction"]
      expect(page).not_to have_text("handwriting transcription")
    end

    describe "work already set to handwriting_transcription" do
      let(:work) { create(:work, text_extraction_mode: "handwriting_transcription") }

      it "still offers, and checks, the current mode" do
        render_component
        expect(page).to have_field("work_text_extraction_mode_handwriting_transcription", checked: true)
      end
    end
  end

  describe "unsaved work, as in new work and batch create forms" do
    let(:work) { Work.new }

    it "offers handwriting transcription, without messages" do
      render_component
      expect(option_values).to include("handwriting_transcription")
      expect(page).not_to have_text("We don't recommend")
    end
  end

  describe "batch edit form" do
    let(:form_object) { Admin::BatchUpdateWorkForm.new({}) }

    it "offers handwriting transcription, without messages" do
      render_component(form_object)
      expect(option_values).to include("handwriting_transcription")
      expect(page).not_to have_text("We don't recommend")
    end
  end

  describe "request status" do
    let(:work) do
      create(:work,
        text_extraction_mode: "handwriting_transcription",
        handwriting_transcription_request: request_attributes
      )
    end

    describe "queued" do
      let(:request_attributes) { { status: "queued" } }

      it "says it is in progress" do
        render_component
        expect(page).to have_text("A handwriting transcription is in progress (status: queued).")
      end
    end

    describe "succeeded" do
      let(:request_attributes) { { status: "success" } }

      it "says so" do
        render_component
        expect(page).to have_text("A handwriting transcription exists for this work.")
      end
    end

    describe "failed" do
      let(:request_attributes) { { status: "failure", error: "Gemini returned HTTP 500" } }

      it "shows the error" do
        render_component
        expect(page).to have_text("The most recent handwriting transcription request failed: Gemini returned HTTP 500")
      end
    end
  end
end
