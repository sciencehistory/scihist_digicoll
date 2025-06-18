require 'rails_helper'

RSpec.describe Admin::AssetTranscriptsController, :logged_in_user, type: :controller, queue_adapter: :test do
  let(:asset) { create(:asset_with_faked_file, :video) }

  describe "set_audio_asr_enabled" do
    it "enqueues job" do
      expect {
        put :set_audio_asr_enabled, params: {
          id: asset.friendlier_id,
          asset: {
            audio_asr_enabled: "1"
          }
        }
      }.to have_enqueued_job(OpenaiAudioTranscribeJob)

      asset.reload
      expect(asset.audio_asr_enabled?).to be true
    end

    describe "if already has ASR vtt" do
      let(:asset) { create(:asset_with_faked_file, :video, :asr_vtt) }

      it "does not enqueue job" do
        expect {
          put :set_audio_asr_enabled, params: {
            id: asset.friendlier_id,
            asset: {
              audio_asr_enabled: "1"
            }
          }
        }.not_to have_enqueued_job(OpenaiAudioTranscribeJob)

        asset.reload
        expect(asset.audio_asr_enabled?).to be true
      end
    end

    describe "disable" do
      let(:asset) { create(:asset_with_faked_file, :video, audio_asr_enabled: true) }

      it "sets to false without enqueing job" do
        expect {
          put :set_audio_asr_enabled, params: {
            id: asset.friendlier_id,
            asset: {
              audio_asr_enabled: "0"
            }
          }
        }.not_to have_enqueued_job(OpenaiAudioTranscribeJob)

        asset.reload
        expect(asset.audio_asr_enabled?).to be false
      end
    end
  end

  describe "#upload_corrected_vtt" do
    it "can upload" do
      put :upload_corrected_vtt, params: {
        id: asset.friendlier_id,
        asset_derivative: {
          Asset::CORRECTED_WEBVTT_DERIVATIVE_KEY => fixture_file_upload("webvtt/simple.vtt")
        }
      }

      expect(response).to have_http_status(:found)

      asset.reload
      expect(asset.corrected_webvtt_str).to eq fixture_file_upload("webvtt/simple.vtt").read.force_encoding("UTF-8")
    end
  end

  it "rejects bad webvtt" do
    put :upload_corrected_vtt, params: {
      id: asset.friendlier_id,
      asset_derivative: {
        Asset::CORRECTED_WEBVTT_DERIVATIVE_KEY => Rack::Test::UploadedFile.new(Rails.root + "spec/test_support/text/0767.txt")
      }
    }

    expect(response).to have_http_status(:found)
    expect(flash[:error]).to eq "Could not upload corrected VTT file: Not a valid WebVTT file"

    asset.reload
    expect(asset.corrected_webvtt_str).to be nil
  end
end
