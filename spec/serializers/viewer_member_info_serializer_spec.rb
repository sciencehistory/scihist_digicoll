require 'rails_helper'

describe ViewerMemberInfoSerializer, type: :decorator do
  let(:grandchild) { create(:asset, :inline_promoted_file).tap { |g| g.reload } }
  let(:child) { create(:work, members: [grandchild], representative: grandchild, position: 2)}
  let(:asset) { create(:asset, :inline_promoted_file, position: 1).tap { |g| g.reload } }
  let(:work)  { create(:work, members: [child, asset, create(:asset, published: false)]) }

  let(:serializer) { ViewerMemberInfoSerializer.new(work) }

  it "serializes" do
    serialized = serializer.as_hash

    expect(serialized).to be_kind_of(Array)
    expect(serialized.length).to eq(2)

    child_serialized = serialized.find { |h| h[:memberId] == child.leaf_representative.friendlier_id }
    expect(child_serialized).to be_present
    expect(child_serialized[:index]).to eq 2
    expect(child_serialized[:memberShouldShowInfo]).to be true
    expect(child_serialized[:title]).to eq child.title
    expect(child_serialized[:memberShowUrl]).to eq helper.work_path(child)
    expect(child_serialized[:tileSource]).to eq child.leaf_representative.dzi_file.url
    expect(child_serialized[:fallbackTileSource]).to eq helper.download_derivative_path(child.leaf_representative, :download_full, disposition: "inline")

    asset_serialized = serialized.find { |h| h[:memberId] == asset.friendlier_id }
    expect(asset_serialized).to be_present
    expect(asset_serialized[:index]).to eq 1
    expect(asset_serialized[:memberShouldShowInfo]).to be false
    expect(asset_serialized[:title]).to eq asset.title
    expect(asset_serialized[:memberShowUrl]).to be nil
    expect(asset_serialized[:tileSource]).to eq asset.dzi_file.url
    expect(asset_serialized[:fallbackTileSource]).to eq helper.download_derivative_path(asset, :download_full, disposition: "inline")
  end
end
