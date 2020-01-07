require 'rails_helper'
RSpec.describe Admin::RAndRItemsController, :logged_in_user, type: :controller do
  describe "R & R controller", logged_in_user: :admin do
    it "can show, create and edit r&r items" do
      expect(Admin::RAndRItem.count).to eq 0
      # List items
      get :index
      expect(response.code).to eq "200"
      # New item form
      get :new
      expect(response.code).to eq "200"
      # Post the form
      r_and_r_params = FactoryBot.attributes_for(:r_and_r_item)
      post :create, params: { admin_r_and_r_item: r_and_r_params }
      expect(Admin::RAndRItem.count).to eq 1
      the_item = Admin::RAndRItem.last
      expect(the_item.title).to eq "Some Item"
      item_id = the_item.id
      # Show the new item:
      get :show, params: {"id"=> item_id}
      expect(response.code).to eq "200"
      # Edit:
      get :edit, params: {"id"=> item_id}
      expect(response.code).to eq "200"
      # Update:
      r_and_r_params[:title] = 'The New Title'
      expect(response.code).to eq "200"
      patch :update, params: { id:item_id,  admin_r_and_r_item: r_and_r_params }
      expect(the_item.reload.title).to eq r_and_r_params[:title]
    end
  end
end
