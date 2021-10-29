require 'rails_helper'


RSpec.describe Admin::AssetsController, :logged_in_user, type: :controller do
  let(:cached_file_param) do
    bytestream = Rails.root + "spec/test_support/images/20x20.png"
    Shrine.storages[:cache].upload(bytestream, "attached_files/sample.png")

    [
      {
        "storage" => "cache",
        "id" => "attached_files/sample.png",
        "metadata" => {
          "filename" => "20x20.png"
        }
      }.to_json
    ]
  end

  let(:parent_work) { create(:work, published: false) }

  describe "#attach_files" do
    it "creates and attaches Asset" do
      post :attach_files, params: { parent_id: parent_work, cached_files: cached_file_param }

      cached_file_param.each do |json|
        file_param = JSON.parse(json)
        child = parent_work.members.find { |a| a.original_filename == file_param["metadata"]["filename"] }
        expect(child).to be_present
        expect(child.published).to eq(parent_work.published)
      end
    end

    describe "with published parent" do
      let(:parent_work) { create(:work, :published) }
      it "attaches asset as published" do
        post :attach_files, params: { parent_id: parent_work, cached_files: cached_file_param }
        expect(parent_work.members).to be_present
        expect(parent_work.members.all? { |m| m.published? }).to be true
      end
      
      context "asset is the representative of the published parent", logged_in_user: :admin do
        let(:asset_child) { create(:asset_with_faked_file, published: true) }
        let(:unpublished_asset_child) { create(:asset_with_faked_file, published: false) }
        let!(:parent_work) { create(:work, :published, members:[asset_child, unpublished_asset_child], representative:asset_child) }
        it "can't be removed" do
          put :destroy, params: { id: asset_child.friendlier_id}
          expect(response).to redirect_to(admin_work_path(parent_work, anchor: "tab=nav-members"))
          expect(flash[:notice]).to match /Could not destroy.*The work is published and this is its representative./
          expect(asset_child.reload).to be_present
          expect(parent_work.reload.representative).to eq asset_child
        end
        it "can't be unpublished" do
          put :update, params: { id: asset_child.friendlier_id, "asset"=>{"published"=>"0"}}
          expect(response).not_to have_http_status(:redirect)
          expect(asset_child.reload.published?).to be true
          expect(parent_work.reload.representative).to eq asset_child
        end
        it "non-representative asset can still be published" do
          put :update, params: { id: unpublished_asset_child.friendlier_id, "asset"=>{"published"=>"1"}}
          expect(response).to have_http_status(:redirect)
          expect(unpublished_asset_child.reload.published?).to be true
        end
      end
    end
  end
end