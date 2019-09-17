require 'rails_helper'

RSpec.describe CatalogController, solr: true, type: :controller do
  describe "redirects searches with legacy params", solr: false do
    describe "sort" do
      let(:legacy_sort) { "system_create_dtsi desc" }
      let(:new_sort) { "recently_added" }

      let(:base_params) { { q: "some search", search_field: "all_fields" } }

      it "redirects" do
        get :index, params: base_params.merge(sort: legacy_sort)
        expect(response).to redirect_to(search_catalog_path(base_params.merge(sort: new_sort)))
      end
    end
  end
end
