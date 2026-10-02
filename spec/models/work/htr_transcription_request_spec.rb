require 'rails_helper'

describe Work::HtrTranscriptionRequest do
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

  describe "stored on a work" do
    let(:work) { create(:work) }

    it "is nil until a request is made" do
      expect(work.htr_transcription_request).to be_nil
    end

    it "round-trips through the database, with a real Time for start_time" do
      now = Time.current
      work.update!(htr_transcription_request: described_class.new(status: "requested", start_time: now))

      reloaded = work.reload.htr_transcription_request

      expect(reloaded).to be_a(described_class)
      expect(reloaded.status).to eq("requested")
      expect(reloaded.start_time).to be_a(Time)
      expect(reloaded.start_time).to be_within(1.second).of(now)
    end

    it "accepts a plain hash" do
      work.update!(htr_transcription_request: { "status" => "failure", "error" => "oops" })

      expect(work.reload.htr_transcription_request).to have_attributes(status: "failure", error: "oops")
    end
  end

  describe "unknown keys" do
    it "are allowed, and kept when serialized" do
      request = described_class.new(status: "requested", model: "gemini-test")

      expect(request.as_json).to include("status" => "requested", "model" => "gemini-test")
    end

    it "don't prevent loading previously-stored data with some other shape" do
      work = create(:work)
      work.update!(htr_transcription_request: { "status" => "error", "errors" => ["an old-style error"] })

      expect(work.reload.htr_transcription_request.status).to eq("error")
    end
  end
end
