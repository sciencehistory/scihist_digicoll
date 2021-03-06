require 'rails_helper'
RSpec.describe Admin::RAndRItemsController, :logged_in_user, type: :controller do
  describe "R & R controller", logged_in_user: :admin do
    let(:r_and_r_item) { FactoryBot.create(:r_and_r_item) }

    it "can show a list of r&r items" do
      expect(Admin::RAndRItem.count).to eq 0
      get :index
      expect(response.code).to eq "200"
    end

    it "can show a new r&r item form" do
      get :new
      expect(response.code).to eq "200"
    end

    it "can create a new r&r item via the form" do
      # Post the form
      r_and_r_params = FactoryBot.attributes_for(:r_and_r_item)
      post :create, params: { admin_r_and_r_item: r_and_r_params }
      expect(Admin::RAndRItem.count).to eq 1
      item = Admin::RAndRItem.last
      expect(item.title).to eq "Some Item"
      # Just by way of making sure the patron and email are indeed
      # encrypted in the DB. The length of the encrypted strings
      # is arbitrary, but shouldn't change unless e.g. the master_key
      # used for our test environment changes first.
      expect(item.patron_name_ciphertext.length).to  eq 56
      expect(item.patron_email_ciphertext.length).to eq 56
    end

    it "it can show a single item" do
      #item = FactoryBot.create(:r_and_r_item)
      get :show, params: {"id"=> r_and_r_item.id}
      expect(response.code).to eq "200"
    end

    it "can show the edit form for an item" do
      #item = FactoryBot.create(:r_and_r_item)
      get :edit, params: {"id"=> r_and_r_item.id}
      expect(response.code).to eq "200"
    end

    it "can update an item using the edit form" do
      r_and_r_params = FactoryBot.attributes_for(:r_and_r_item)
      #item = FactoryBot.create(:r_and_r_item)
      r_and_r_params[:title] = 'The New Title'
      patch :update, params: { id:r_and_r_item.id,  admin_r_and_r_item: r_and_r_params }
      expect(response.code).to eq "302"
      expect(r_and_r_item.reload.title).to eq r_and_r_params[:title]
    end

    it "can delete an item" do
      #item = FactoryBot.create(:r_and_r_item)
      #expect(Admin::RAndRItem.count).to eq 1
      get :destroy, params: {"id"=> r_and_r_item.id}
      expect(response.code).to eq "302"
      expect(response.location).to eq admin_r_and_r_items_url
      expect(Admin::RAndRItem.count).to eq 0
    end
  end
end
