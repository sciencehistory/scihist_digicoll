require 'rails_helper'

describe OralHistoryContent do
  let(:work) { create(:work) }
  let(:oral_history_content) { work.create_oral_history_content }
  let(:mp3_path) { Rails.root + "spec/test_support/audio/ice_cubes.mp3" }
  let(:webm_path) { Rails.root + "spec/test_support/audio/smallest_webm.webm" }

  describe "#set_combined_audio_mp3!" do
    it "can set" do
      oral_history_content.set_combined_audio_mp3!(File.open(mp3_path))

      expect(oral_history_content.changed?).to be(false)
      expect(oral_history_content.combined_audio_mp3).to be_present
      expect(oral_history_content.combined_audio_mp3.read).to eq(File.read(mp3_path, encoding: "BINARY"))
      expect(oral_history_content.combined_audio_mp3.size).to eq(File.size(mp3_path))

      expect(oral_history_content.combined_audio_mp3.original_filename).to eq("combined.mp3")
      expect(oral_history_content.combined_audio_mp3.mime_type).to eq("audio/mpeg")

      expect(oral_history_content.combined_audio_mp3.id).to match(/#{work.id}\/combined_[a-f0-9]+\.mp3/)
    end

    describe "for failed save" do
      it "doesn't leave behind file in storage" do
        allow(oral_history_content).to receive(:save!).and_raise("mock error")

        expect {
          oral_history_content.set_combined_audio_mp3!(File.open(mp3_path))
        }.to raise_error("mock error")

        expect(oral_history_content.changed?).to be(false)
        expect(oral_history_content.combined_audio_mp3).not_to be_present
      end
    end
  end

  describe "#set_combined_audio_webm!" do
    it "can set" do
      oral_history_content.set_combined_audio_webm!(File.open(webm_path))

      expect(oral_history_content.changed?).to be(false)
      expect(oral_history_content.combined_audio_webm).to be_present
      expect(oral_history_content.combined_audio_webm.read).to eq(File.read(webm_path, encoding: "BINARY"))
      expect(oral_history_content.combined_audio_webm.size).to eq(File.size(webm_path))
      expect(oral_history_content.combined_audio_webm.original_filename).to eq("combined.webm")
      expect(oral_history_content.combined_audio_webm.mime_type).to eq("audio/webm")
    end
  end

  describe "work#oral_history_content!" do
    describe "without existing sidecar" do
      it "creates one" do
        expect(work.oral_history_content).to be_nil
        result = work.oral_history_content!

        expect(result).to be_present
        expect(work.oral_history_content).to be_present
        expect(result).to equal(work.oral_history_content)
      end
    end

    describe "with existing content" do
      it "returns existing" do
        existing = oral_history_content
        expect(existing).to equal(work.oral_history_content)

        result = work.oral_history_content!
        expect(result).to equal(work.oral_history_content)
        expect(result).to equal(existing)
      end
    end

    describe "with concurrently created content" do
      it "is handles" do
        # pre-conditions
        expect(work.oral_history_content).to be_nil
        concurrent = OralHistoryContent.create!(work_id: work.id)
        expect(work.oral_history_content).to be_nil

        result = work.oral_history_content!
        expect(result.id).to equal(concurrent.id)
      end
    end
  end
end
