require 'rails_helper'

RSpec.describe Admin::AssetTranscriptsController, :logged_in_user, type: :controller do
  let(:asset) { create(:asset_with_faked_file, :video) }

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
      expect(asset.corrected_webvtt_str).to eq fixture_file_upload("webvtt/simple.vtt").read
    end
  end
end
