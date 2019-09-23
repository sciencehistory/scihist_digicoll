require 'rails_helper'

# mostly we use feature tests, but some things can't easily be tested that way
# Should this be a 'request' spec instead of a rspec 'controller' spec
# (that is a rails 'functional' test)?
RSpec.describe CollectionShowController, :logged_in_user, solr: true, type: :controller do
  describe "unpublished collection" do
    let(:collection) { create(:collection, published: false) }

    describe "non-logged-in user", logged_in_user: false do
      it "has permission denied" do
        get :index, params: { collection_id: collection.friendlier_id }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    describe "logged-in user", logged_in_user: true do
      it "can see page" do
        get :index, params: { collection_id: collection.friendlier_id }
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "redirects searches with legacy params", solr: false do
    let(:collection_id) { "faked" }
    describe "sort" do
      let(:legacy_sort) { "system_create_dtsi desc" }
      let(:new_sort) { "recently_added" }

      let(:base_params) { { collection_id: collection_id, q: "some search", search_field: "all_fields" } }

      it "redirects" do
        get :index, params: base_params.merge(sort: legacy_sort)
        expect(response).to redirect_to(collection_path(base_params.merge(sort: new_sort)))
      end
    end
  end


end
