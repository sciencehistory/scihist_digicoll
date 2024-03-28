require 'rails_helper'

describe ViewerMemberInfoSerializer, type: :model, queue_adapter: :inline do
  include Rails.application.routes.url_helpers

  let(:grandchild) { create(:asset, :inline_promoted_file, file: File.open(Rails.root + "spec/test_support/images/mini_page_scan.tiff")).tap { |g| g.reload } }
  let(:child) { create(:public_work, members: [grandchild], representative: grandchild, position: 2)}
  let(:asset) { create(:asset, :inline_promoted_file, position: 1, file: File.open(Rails.root + "spec/test_support/images/mini_page_scan.tiff")).tap { |g| g.reload } }
  let(:non_published_asset) { create(:asset, :inline_promoted_file, file: File.open(Rails.root + "spec/test_support/images/mini_page_scan.tiff"), published: false) }
  let(:work)  { create(:public_work, members: [child, asset, non_published_asset]) }

  let(:serializer) { BookReaderDataSerializer.new(work) }

  it "serializes" do
    serialized = serializer.as_array

    expect(serialized).to be_kind_of(Array)
    # two arrays of one item each
    expect(serialized.length).to eq 2
    expect(serialized.first.length).to eq 1
    expect(serialized.second.length).to eq 1

    flattened = serialized.flatten

    # direct asset and the child works' representative should be in there
    [asset, child.leaf_representative].each do |a|
      asset_serialized = flattened.find { |h| h[:assetId] == a.friendlier_id }
      expect(asset_serialized).to be_present
      expect(asset_serialized[:title]).to eq a.title
      expect(asset_serialized[:width]).to be_present
      expect(asset_serialized[:width]).to eq a.width
      expect(asset_serialized[:height]).to be_present
      expect(asset_serialized[:height]).to eq a.height

      expect(asset_serialized[:dpi]).to be_present
      expect(asset_serialized[:dpi]).to eq a.file_metadata["dpi"]

      # supposed to be hash of width to derivative url
      expect(asset_serialized[:img_by_width]).to be_kind_of(Hash)
      expect(asset_serialized[:img_by_width]).to be_present
      expect(asset_serialized[:img_by_width].keys.all? { |k| k.kind_of?(Integer)}).to be true
      expect(asset_serialized[:img_by_width].values.all? { |k| k.kind_of?(String)}).to be true
    end

    non_published = flattened.find { |h| h[:assetId] == non_published_asset.friendlier_id }
    expect(non_published).not_to be_present
  end


  describe "with show_unpublished:true" do
    let(:serializer) { BookReaderDataSerializer.new(work, show_unpublished: true) }
    it "includes non-published asset" do
      serialized = serializer.as_array

      expect(serialized).to be_kind_of(Array)
      # array of one, and array of 2
      expect(serialized.length).to eq 2
      expect(serialized.first.length).to eq 1
      expect(serialized.second.length).to eq 2

      non_published = serialized.flatten.find { |h| h[:assetId] == non_published_asset.friendlier_id }
      expect(non_published).to be_present
    end
  end
end
