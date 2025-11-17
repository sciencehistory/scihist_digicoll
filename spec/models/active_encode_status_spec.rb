require 'rails_helper'

RSpec.describe ActiveEncodeStatus, type: :model do


  def mocked_active_encode_result(state: :running, percent_complete: 0, encode_error: nil)
    ActiveEncode::Base.new("s3://mocked-input-url/something.mp4", {}).tap do |encode|
      encode.id =  "faked-id"
      encode.state = state
      encode.percent_complete = percent_complete
      encode.errors = [encode_error].compact
      encode.output = [
        ActiveEncode::Output.new.tap do |output|
          s3_url = "s3://#{File.join('faked-output-bucket', Shrine.storages[:video_derivatives].prefix.to_s, 'somewhere/hls.m3u8')}"

          output.id = "fake"
          output.label = "hls.m3u8"
          output.url = s3_url
        end,
        ActiveEncode::Output.new.tap do |output|
          s3_url = "s3://#{File.join('faked-output-bucket', Shrine.storages[:video_derivatives].prefix.to_s, 'wrong/hls_low.m3u8')}"

          output.id = "fake"
          output.label = "hls_low.m3u8"
          output.url = s3_url
          output.height = 420
        end
      ]
    end
  end

  let(:asset) { create(:asset_with_faked_file, :video) }

  let(:active_encode_status) do
    ActiveEncodeStatus.create_from!(asset: asset,
                                    active_encode_result: mocked_active_encode_result)
  end

  describe "#refresh_from_aws" do
    before do
      # mock it to simulate an S3 bucket so we can test.
      without_partial_double_verification do
        allow(Shrine.storages[:video_derivatives]).to receive(:bucket).and_return(OpenStruct.new(name: "faked-output-bucket"))
      end
    end

    let(:expected_s3_url) do
      "s3://#{File.join('faked-output-bucket', Shrine.storages[:video_derivatives].prefix.to_s, 'somewhere/hls.m3u8')}"
    end

    it "sets result in Asset" do
      expect(ActiveEncode::Base).to receive(:find).
        with(active_encode_status.active_encode_id).
        and_return(mocked_active_encode_result(state: :completed, percent_complete: 100))

      active_encode_status.refresh_from_aws

      asset.reload

      expect(asset.hls_playlist_file).to be_present
      expect(asset.hls_playlist_file.id).to eq("somewhere/hls.m3u8")
    end

    it "raises on failure" do
      expect(ActiveEncode::Base).to receive(:find).
        with(active_encode_status.active_encode_id).
        and_return(mocked_active_encode_result(state: :failed, encode_error: "mocked failure"))

      expect {
        active_encode_status.refresh_from_aws
      }.to raise_error(ActiveEncodeStatus::EncodeFailedError, "Asset: #{asset.friendlier_id}, mocked failure")
    end

    describe "for asset no longer present on completion" do
      before do
        Asset.where(id: active_encode_status.asset_id).delete_all
        # so it doesn't refer to an in-memory but deleted asset, for better test!
        active_encode_status.reload
      end

      it "deletes leftover files" do
        expect(ActiveEncode::Base).to receive(:find).
          with(active_encode_status.active_encode_id).
          and_return(mocked_active_encode_result(state: :completed, percent_complete: 100))

        expect(Shrine.storages[:video_derivatives]).to receive(:delete_prefixed).with("somewhere/")
        expect(Rails.logger).to receive(:error).with(/^Deleting leftover HLS files for apparently missing asset ID: #{active_encode_status.asset_id}/)

        active_encode_status.refresh_from_aws

        expect(active_encode_status.asset_id).to be_present
        expect(active_encode_status.asset).to be nil
        expect(active_encode_status.completed?).to be true
      end
    end

  end
end
