require 'rails_helper'

RSpec.describe Admin::CollectionsController, :logged_in_user, type: :controller do
  describe "admin user", logged_in_user: :admin do
    it "can create a published collection" do
      post :create, params: { collection: { title: "newly created collection", published: "1" } }
      newly_created = Collection.find_by_title("newly created collection")
      expect(newly_created).to be_present
      expect(newly_created.published?).to be true
    end
  end
end
