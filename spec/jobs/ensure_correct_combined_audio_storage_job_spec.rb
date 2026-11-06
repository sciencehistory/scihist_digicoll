require 'rails_helper'

describe EnsureCorrectCombinedAudioStorageJob do
  let(:work) { create(:oral_history_work, :combined_derivative) }
  let(:oral_history_content) { work.oral_history_content }

  it "does nothing if storage is correct" do
    original_id = oral_history_content.combined_audio_m4a.id
    expect {
      described_class.perform_now(oral_history_content)
    }.not_to have_enqueued_job(CreateCombinedAudioDerivativesJob)
    expect(oral_history_content.reload.combined_audio_m4a.id).to eq original_id
  end

  describe "with public file for non-direct oral history" do
    before do
      # skip the callback so we can call the job directly
      oral_history_content.update_columns(availability_mode: "automatic_request")
      oral_history_content.reload
    end

    it "deletes the file and queues regeneration" do
      old_file = oral_history_content.combined_audio_m4a
      expect(old_file.storage_key).to eq :combined_audio_derivatives

      expect {
        described_class.perform_now(oral_history_content)
      }.to have_enqueued_job(CreateCombinedAudioDerivativesJob).with(work)

      oral_history_content.reload
      expect(oral_history_content.combined_audio_m4a).to be_nil
      expect(oral_history_content.combined_audio_fingerprint).to be_nil
      expect(old_file.exists?).to be false
    end
  end

  describe "with any file for embargoed oral history" do
    before do
      oral_history_content.update_columns(availability_mode: "embargoed")
      oral_history_content.reload
    end

    it "deletes the file" do
      old_file = oral_history_content.combined_audio_m4a
      described_class.perform_now(oral_history_content)

      expect(oral_history_content.reload.combined_audio_m4a).to be_nil
      expect(old_file.exists?).to be false
    end
  end
end
