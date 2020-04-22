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
    end
  end

  context "published audio history" do
    let(:oral_history)   { create( :public_work, genre: ["Oral histories"]) }
    let(:audio_asset_1)  { create(:asset, parent_id: oral_history.id ) }
    it "locks down most of the functionality on the asset list page" do
      get :edit, params: { id: audio_asset_1.friendlier_id }
      expect(response).to redirect_to(admin_work_path(oral_history, anchor: "nav-members"))
      expect(flash[:alert]).to match /Please unpublish.*modify/
      get :destroy, params: { id: audio_asset_1.friendlier_id }
      expect(response).to redirect_to(admin_work_path(oral_history, anchor: "nav-members"))
      expect(flash[:alert]).to match /Please unpublish.*delet/
      get :display_attach_form, params: { parent_id: oral_history.friendlier_id }
      expect(response).to redirect_to(admin_work_path(oral_history, anchor: "nav-members"))
      expect(flash[:alert]).to match /Please unpublish.*add/
      get :convert_to_child_work, params: { id: audio_asset_1.friendlier_id }
      expect(response).to redirect_to(admin_work_path(oral_history, anchor: "nav-members"))
      expect(flash[:alert]).to match /Please unpublish.*modify/
    end
  end
end
