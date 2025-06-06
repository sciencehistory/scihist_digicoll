require 'rails_helper'

RSpec.describe Admin::CollectionsController, :logged_in_user, type: :controller do
  describe "admin user", logged_in_user: :admin do
    it "can create a published collection" do
      post :create, params: { collection: { title: "newly created collection", published: "1", department: "Archives" } }
      newly_created = Collection.find_by_title("newly created collection")
      expect(newly_created).to be_present
      expect(newly_created.published?).to be true
    end

    context "filter collections" do
      render_views
      let!(:collection) {
        create(:collection, external_id: [
          Work::ExternalId.new( {"value"=>"2010.028",   "category"=>"accn"} ),
        ])
      }
      it "can filter on external id, regardless of the category of the ID" do
        get :index, params: { title_or_id: "2010.028" }
        rows = response.parsed_body.css('.table.admin-list tbody tr')
        expect(rows.length).to eq 1
      end
    end
  end
end
