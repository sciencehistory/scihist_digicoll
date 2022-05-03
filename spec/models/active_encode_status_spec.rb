require 'rails_helper'

RSpec.describe ActiveEncodeStatus, type: :model do


  def mocked_active_encode_result(state: :running, percent_complete: 0)
    ActiveEncode::Base.new("s3://mocked-input-url/something.mp4", {}).tap do |encode|
      encode.id =  "faked-id"
      encode.state = state
      encode.percent_complete = percent_complete
      encode.errors = []
      encode.output = [
        ActiveEncode::Output.new.tap do |output|
          s3_url = "s3://#{File.join('faked-output-bucket', Shrine.storages[:video_derivatives].prefix.to_s, 'somewhere/hls.m3u8')}"

          output.id = "fake"
          output.url = s3_url
        end,
        ActiveEncode::Output.new.tap do |output|
          s3_url = "s3://#{File.join('faked-output-bucket', Shrine.storages[:video_derivatives].prefix.to_s, 'wrong/hls_low.m3u8')}"

          output.id = "fake"
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
  end
end
