# spec/helpers/google_arts_and_culture_serializer_helper_spec.rb
require 'rails_helper'

RSpec.describe GoogleArtsAndCultureSerializerHelper, type: :helper do
  # We’ll reuse the same kind of factories as in your other specs.
  let!(:work) do
    create(
      :public_work,
      members: [
        create(:asset_with_faked_file, faked_content_type: "image/tiff"),
        create(:asset_with_faked_file, faked_content_type: "image/tiff")
      ]
    )
  end

  let(:assets) { work.members.to_a }

  describe "#members_to_include" do
    it "returns a collection of members for a work" do
      result = helper.members_to_include(work)
      expect(result).to be_an(Enumerable)
      expect(result).to include(*assets)
    end
  end

  describe "#filename_from_asset" do
    let(:asset) { assets.first }
    it "returns a string filename for the given asset" do
      expect(helper.filename_from_asset(asset)).to eq "test_title_#{asset.parent.friendlier_id}_#{asset.friendlier_id}.jpg"
    end
  end

  describe "#asset_filetype" do
    let(:asset) { assets.first }
    it "returns some representation of the asset filetype" do
      filetype = helper.asset_filetype(asset)
      expect(filetype).to eq "Image"
    end
  end

  describe "#file_to_include" do
    let(:asset) { assets.first }
    it "returns an uploaded file" do
      uploaded = helper.file_to_include(asset)
      expect(uploaded.class).to eq AssetUploader::UploadedFile
    end
  end
end
