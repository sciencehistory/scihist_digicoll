require 'rails_helper'

describe ViewerMemberInfoSerializer, type: :model, queue_adapter: :inline do
  include Rails.application.routes.url_helpers

  let(:grandchild) { create(:asset, :inline_promoted_file).tap { |g| g.reload } }
  let(:child) { create(:public_work, members: [grandchild], representative: grandchild, position: 2)}
  let(:asset) { create(:asset, :inline_promoted_file, position: 1).tap { |g| g.reload } }
  let(:non_published_asset) { create(:asset, :inline_promoted_file, published: false) }
  let(:work)  { create(:public_work, members: [child, asset, non_published_asset]) }

  let(:serializer) { ViewerMemberInfoSerializer.new(work) }

  it "serializes" do
    serialized = serializer.as_hash

    expect(serialized).to be_kind_of(Array)
    expect(serialized.length).to eq(2)

    child_serialized = serialized.find { |h| h[:memberId] == child.friendlier_id }
    expect(child_serialized).to be_present
    expect(child_serialized[:index]).to eq 2
    expect(child_serialized[:memberShouldShowInfo]).to be true
    expect(child_serialized[:title]).to eq child.title
    expect(child_serialized[:memberShowUrl]).to eq work_path(child)
    expect(child_serialized[:tileSource]).to eq child.leaf_representative.dzi_file.url
    expect(child_serialized[:fallbackTileSource]).to eq({ type: "image", url: download_derivative_path(child.leaf_representative, :download_medium, disposition: "inline")})
    expect(child_serialized[:downloads]).to be_kind_of(Array)
    expect(child_serialized[:downloads]).to be_present
    expect(child_serialized[:downloads].all? {|d| d[:url].present?}).to be true

    asset_serialized = serialized.find { |h| h[:memberId] == asset.friendlier_id }
    expect(asset_serialized).to be_present
    expect(asset_serialized[:index]).to eq 1
    expect(asset_serialized[:memberShouldShowInfo]).to be false
    expect(asset_serialized[:title]).to eq asset.title
    expect(asset_serialized[:memberShowUrl]).to be nil
    expect(asset_serialized[:tileSource]).to eq asset.dzi_file.url
    expect(asset_serialized[:fallbackTileSource]).to eq({ type: "image", url: download_derivative_path(asset, :download_medium, disposition: "inline") })
    expect(child_serialized[:downloads]).to be_kind_of(Array)
    expect(child_serialized[:downloads]).to be_present
    expect(child_serialized[:downloads].all? {|d| d[:url].present?}).to be true

    non_published = serialized.find { |h| h[:memberId] == non_published_asset.friendlier_id }
    expect(non_published).not_to be_present
  end

  describe "with logged-in user" do
    let(:current_user) { create(:user) }
    let(:serializer) { ViewerMemberInfoSerializer.new(work, current_user: current_user) }

    it "includes non-published asset" do
      serialized = serializer.as_hash

      expect(serialized).to be_kind_of(Array)
      expect(serialized.length).to eq(3)

      non_published = serialized.find { |h| h[:memberId] == non_published_asset.friendlier_id }
      expect(non_published).to be_present
    end
  end
end
