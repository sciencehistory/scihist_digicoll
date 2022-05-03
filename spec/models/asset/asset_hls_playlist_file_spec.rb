require 'rails_helper'

# This is kind of crazy testing, my apologies.
describe "Asset#hls_playlist_file", queue_adapter: :inline do
  let(:faked_bucket_name) { "faked-bucket" }
  let(:storage_key) { :video_derivatives }

  let(:video_derivatives_storage) do
    Shrine.storages[storage_key].tap do |storage|
      # mock it to simulate an S3 bucket so we can test.
      without_partial_double_verification do
        allow(storage).to receive(:bucket).and_return(OpenStruct.new(name: faked_bucket_name))
      end
    end
  end

  let(:existing_playlist_path) {  "an_asset_uuid/a_random_number" }

  let(:existing_hls_playlist_key) do
    File.join(existing_playlist_path, "hls.m38u").tap do |path|
      video_derivatives_storage.upload(StringIO.new("fake_playlist"), path)
    end
  end

  let(:existing_hls_segment_key) do
    File.join(existing_playlist_path, "hls_1.ts").tap do |path|
      video_derivatives_storage.upload(StringIO.new("fake_segment"), path)
    end
  end

  let(:playlist_s3_url) { "s3://#{File.join(faked_bucket_name, video_derivatives_storage.prefix, existing_hls_playlist_key)}" }

  let(:asset) { create(:asset_with_faked_file, :video) }

  describe "#hls_playlist_file_as_s3=" do
    it "can set to existing file location" do
      asset.hls_playlist_file_as_s3 = playlist_s3_url

      expect(asset.hls_playlist_file.exists?).to be(true), "Shrine attachment does not point to existing file"

      asset.save!

      expect(asset.hls_playlist_file.exists?).to be(true), "Shrine attachment does not point to existing file"

      asset.reload

      expect(asset.hls_playlist_file.exists?).to be(true), "Shrine attachment does not point to existing file"
    end
  end

  describe "deletion of existing hls files" do
    let(:previous_playlist_uploaded_file) {
      asset.hls_playlist_file_attacher.uploaded_file(storage: storage_key, id: existing_hls_playlist_key )
    }

    let(:previous_segment_uploaded_file) {
      asset.hls_playlist_file_attacher.uploaded_file(storage: storage_key, id: existing_hls_segment_key )
    }

    before do
      asset.hls_playlist_file_as_s3 = playlist_s3_url
      asset.save!

      expect(previous_playlist_uploaded_file.exists?).to be(true)
      expect(previous_segment_uploaded_file.exists?).to be(true)
    end

    it "happens on destroy" do
      asset.destroy!

      expect(previous_playlist_uploaded_file.exists?).to be(false)
      expect(previous_segment_uploaded_file.exists?).to be(false)
    end

    it "happens on reassign" do
      asset.hls_playlist_file_as_s3 = "s3://#{File.join(faked_bucket_name, video_derivatives_storage.prefix, '/')}"
      asset.save!

      expect(previous_playlist_uploaded_file.exists?).to be(false)
      expect(previous_segment_uploaded_file.exists?).to be(false)
    end
  end
end
