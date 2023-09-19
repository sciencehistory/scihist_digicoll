require 'rails_helper'
RSpec.describe CollectionShowControllers::OralHistoryCollectionController, :logged_in_user, solr: true, type: :controller do
  describe "Oral history collection facets" do
    let(:oh_collection) { create(:collection,
        friendlier_id: ScihistDigicoll::Env.lookup!("oral_history_collection_id")) }

    it "handles unpermitted params" do
      get :facet, params: {
        id:              "oh_institution_facet",
        collection_id:   oh_collection.friendlier_id,
        "facet.page" =>  { goat: 'goat' }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end