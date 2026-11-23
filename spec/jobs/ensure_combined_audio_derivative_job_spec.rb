require 'rails_helper'

describe EnsureCombinedAudioDerivativeJob do
  let(:work) { create(:oral_history_work, :combined_derivative) }
  let(:oral_history_content) { work.oral_history_content }
  let(:m4a_path) { Rails.root + "spec/test_support/audio/5-seconds-of-silence.m4a" }

  # real ffmpeg can't run on faked factory files
  before do
    allow_any_instance_of(CombinedAudioDerivativeCreator).to receive(:generate) do |creator|
      tmp = Tempfile.new(["combined", ".m4a"]).tap(&:binmode)
      tmp.write(File.binread(m4a_path))
      tmp.flush
      tmp.rewind
      CombinedAudioDerivativeCreator::Response.new(m4a_file: tmp, fingerprint: creator.fingerprint, start_times: creator.calculate_start_times)
    end
  end

  it "does nothing if current" do
    original_id = oral_history_content.combined_audio_m4a.id
    expect_any_instance_of(CombinedAudioDerivativeCreator).not_to receive(:generate)

    described_class.perform_now(work)

    expect(oral_history_content.reload.combined_audio_m4a.id).to eq original_id
  end

  it "re-creates if current with force" do
    old_file = oral_history_content.combined_audio_m4a

    described_class.perform_now(work, force: true)

    oral_history_content.reload
    expect(oral_history_content.combined_audio_m4a.id).not_to eq old_file.id
    expect(old_file.exists?).to be false
    expect(oral_history_content.combined_audio_derivatives_job_status).to eq "succeeded"
  end

  it "re-creates if stale" do
    oral_history_content.update_columns(combined_audio_fingerprint: "stale")
    old_file = oral_history_content.combined_audio_m4a

    described_class.perform_now(work)

    oral_history_content.reload
    expect(oral_history_content.combined_audio_up_to_date?).to be true
    expect(old_file.exists?).to be false
  end

  describe "with public file for non-direct oral history" do
    before do
      # skip the callback so we can call the job directly
      oral_history_content.update_columns(availability_mode: "automatic_request")
    end

    it "deletes and re-creates in restricted storage" do
      old_file = oral_history_content.combined_audio_m4a
      expect(old_file.storage_key).to eq :combined_audio_derivatives

      described_class.perform_now(work)

      oral_history_content.reload
      expect(old_file.exists?).to be false
      expect(oral_history_content.combined_audio_m4a.storage_key).to eq :restricted_combined_audio_derivatives
      expect(oral_history_content.combined_audio_good?).to be true
    end
  end

  describe "with any file for embargoed oral history" do
    before do
      oral_history_content.update_columns(availability_mode: "embargoed")
    end

    it "deletes the file, does not re-create" do
      old_file = oral_history_content.combined_audio_m4a
      expect_any_instance_of(CombinedAudioDerivativeCreator).not_to receive(:generate)

      described_class.perform_now(work)

      oral_history_content.reload
      expect(oral_history_content.combined_audio_m4a).to be_nil
      expect(oral_history_content.combined_audio_fingerprint).to be_nil
      expect(old_file.exists?).to be false
    end
  end

  describe "with no available audio" do
    before do
      work.members.each { |m| m.update_columns(published: false) if m.content_type&.start_with?("audio/") }
    end

    it "deletes the file, does not re-create" do
      old_file = oral_history_content.combined_audio_m4a
      expect_any_instance_of(CombinedAudioDerivativeCreator).not_to receive(:generate)

      described_class.perform_now(work)

      expect(oral_history_content.reload.combined_audio_m4a).to be_nil
      expect(old_file.exists?).to be false
    end
  end
end
