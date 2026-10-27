require 'rails_helper'

describe Work::HandwritingTranscriptionRequest do
  describe "status predicates" do
    it "is neither pending nor finished with no status" do
      request = described_class.new

      expect(request).not_to be_pending
      expect(request).not_to be_finished
    end

    %w{started requested received}.each do |status|
      it "is pending, not finished, when #{status}" do
        request = described_class.new(status: status)

        expect(request).to be_pending
        expect(request).not_to be_finished
      end
    end

    it "is finished and successful on success" do
      request = described_class.new(status: "success")

      expect(request).to be_success
      expect(request).not_to be_failure
      expect(request).to be_finished
      expect(request).not_to be_pending
    end

    it "is finished and failed on failure" do
      request = described_class.new(status: "failure", error: "it broke")

      expect(request).to be_failure
      expect(request).not_to be_success
      expect(request).to be_finished
      expect(request).not_to be_pending
    end
  end

  describe "#status_message" do
    it "is nil with no status" do
      expect(described_class.new.status_message).to be_nil
    end

    it "describes a request in progress" do
      expect(described_class.new(status: "queued").status_message).to eq("A handwriting transcription is in progress (status: queued).")
    end

    it "describes success" do
      expect(described_class.new(status: "success").status_message).to eq("A handwriting transcription exists for this work.")
    end

    it "includes the error on failure" do
      expect(described_class.new(status: "failure", error: "it broke").status_message).to eq(
        "The most recent handwriting transcription request failed: it broke"
      )
    end

    it "copes with a failure that has no error" do
      expect(described_class.new(status: "failure").status_message).to end_with("failed: unknown error")
    end
  end

  describe "stored on a work" do
    let(:work) { create(:work) }

    it "is nil until a request is made" do
      expect(work.handwriting_transcription_request).to be_nil
    end

    it "round-trips through the database, with a real Time for start_time" do
      now = Time.current
      work.update!(handwriting_transcription_request: described_class.new(status: "requested", start_time: now))

      reloaded = work.reload.handwriting_transcription_request

      expect(reloaded).to be_a(described_class)
      expect(reloaded.status).to eq("requested")
      expect(reloaded.start_time).to be_a(Time)
      expect(reloaded.start_time).to be_within(1.second).of(now)
    end

    it "accepts a plain hash" do
      work.update!(handwriting_transcription_request: { "status" => "failure", "error" => "oops" })

      expect(work.reload.handwriting_transcription_request).to have_attributes(status: "failure", error: "oops")
    end
  end

  describe "unknown keys" do
    it "are allowed, and kept when serialized" do
      request = described_class.new(status: "requested", model: "gemini-test")

      expect(request.as_json).to include("status" => "requested", "model" => "gemini-test")
    end

    it "don't prevent loading previously-stored data with some other shape" do
      work = create(:work)
      work.update!(handwriting_transcription_request: { "status" => "failure", "errors" => ["an old-style error"] })

      expect(work.reload.handwriting_transcription_request.status).to eq("failure")
    end
  end
end
