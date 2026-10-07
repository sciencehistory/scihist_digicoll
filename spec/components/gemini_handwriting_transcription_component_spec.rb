require 'rails_helper'

describe GeminiHandwritingTranscriptionComponent, type: :component do
  let(:work) { create(:public_work) }
  let(:component) { described_class.new(work) }
  let(:start_time) { Time.zone.parse("2026-01-01 12:30:00") }

  before do
    allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
    allow(ScihistDigicoll::Env).to receive(:lookup).with(:gemini_htr_transcripts_feature_flag).and_return(true)
  end

  def store_request(**attributes)
    work.update!(handwriting_transcription_request: Work::HandwritingTranscriptionRequest.new(**attributes))
  end

  describe "with no request ever made" do
    it "offers a plain button and no status message" do
      expect(component.current_request).to be_nil
      expect(component.request_pending?).to be false
      expect(component.request_button_label).to eq("Request transcription")

      result = render_inline(component)
      expect(result.text).to include("Request transcription")
      expect(result.text).not_to include("It's not ready yet")
    end
  end

  describe "with a request in progress" do
    %w{started requested received}.each do |status|
      it "hides the button when #{status}" do
        store_request(status: status, start_time: start_time)

        expect(component.request_pending?).to be true

        result = render_inline(component)
        expect(result.text).to include("It's not ready yet")
        expect(result.text).not_to include("Request transcription")
      end
    end
  end

  describe "with a successful request" do
    before { store_request(status: "success", start_time: start_time) }

    it "reports success, links to the transcript, and offers to replace it" do
      expect(component.request_pending?).to be false

      result = render_inline(component)
      expect(result.text).to include("An automatic transcript exists; it was created on 2026-Jan-01 12:30")
      expect(result.text).to include("Request a new transcription to replace the current one")

      link = result.css("a").find { |a| a.text.include?("view transcript") }
      expect(link["href"]).to eq("/works/#{work.friendlier_id}#tab=handwriting-transcription")
    end
  end

  describe "with a failed request" do
    before { store_request(status: "failure", error: "it broke", start_time: start_time) }

    it "reports the failure and its error, and offers a plain button to try again" do
      expect(component.request_pending?).to be false

      result = render_inline(component)
      expect(result.text).to include("but it failed. The error was: it broke")
      expect(result.text).to include("Request transcription")
      expect(result.text).not_to include("replace the current one")
    end

    it "escapes the error message" do
      store_request(status: "failure", error: "<b>bold</b> trouble", start_time: start_time)

      result = render_inline(component)
      expect(result.css("b")).to be_empty
      expect(result.text).to include("<b>bold</b> trouble")
    end

    it "falls back to a generic message when there is no error text" do
      store_request(status: "failure", start_time: start_time)

      expect(render_inline(component).text).to include("more information is available in the logs")
    end
  end

  describe "delete button" do
    def delete_link(result)
      result.css("a").find { |a| a.text.strip == "Delete transcript" }
    end

    it "is offered, with a confirmation, when there is a transcript" do
      store_request(status: "success", start_time: start_time)

      expect(component.transcript_exists?).to be true

      link = delete_link(render_inline(component))
      expect(link["href"]).to eq("/admin/works/delete_handwriting_transcription/#{work.friendlier_id}")
      expect(link["data-method"]).to eq("delete")
      expect(link["data-confirm"]).to eq("Are you sure you want to delete this transcript?")
    end

    it "is not offered when no request has been made" do
      expect(component.transcript_exists?).to be false
      expect(delete_link(render_inline(component))).to be_nil
    end

    %w{started requested received failure}.each do |status|
      it "is not offered when the request is #{status}" do
        store_request(status: status, start_time: start_time)

        expect(component.transcript_exists?).to be false
        expect(delete_link(render_inline(component))).to be_nil
      end
    end
  end

  describe "when the work isn't eligible" do
    it "explains why, rather than offering a button" do
      allow_any_instance_of(GeminiHandwritingTranscriptionService)
        .to receive(:work_eligibility_problems).and_return(["no usable images were found"])

      result = render_inline(component)
      expect(result.text).to include("This work isn't eligible, as no usable images were found.")
      expect(result.text).not_to include("Request transcription")
    end
  end

  describe "when the feature flag is off" do
    it "renders nothing about transcription" do
      allow(ScihistDigicoll::Env).to receive(:lookup).with(:gemini_htr_transcripts_feature_flag).and_return(false)

      expect(render_inline(component).text).not_to include("Request transcription")
    end
  end
end
