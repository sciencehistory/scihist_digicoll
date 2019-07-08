require 'rails_helper'

describe DownloadsController do
  let(:asset) { create(:asset, :inline_promoted_file) }

  describe "#original" do
    describe "non-existing ID" do
      it "raises not found" do
        expect {
          get :original, params: { asset_id: "no_such_id" }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe "no access asset" do
      let(:asset) { create(:asset, published: false) }
      it "redirects to login page" do
        get :original, params: { asset_id: asset }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

  end


  describe "#derivative" do
    describe "non-existing ID" do
      it "raises not found" do
        expect {
          get :derivative, params: { asset_id: "no_such_id", derivative_key: "thumb_mini" }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe "no access asset" do
      let(:asset) { create(:asset, published: false) }
      it "redirects to login page" do
        get :original, params: { asset_id: asset, derivatives_key: "thumb_mini" }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    describe "derivative does not exist" do
      let(:asset) { create(:asset, :inline_promoted_file, :no_derivatives_creation) }

      it "raises not found" do
        expect {
          get :derivative, params: { asset_id: asset, derivative_key: "thumb_mini" }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
