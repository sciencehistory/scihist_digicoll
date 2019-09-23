require 'rails_helper'

RSpec.describe CatalogController, solr: true, type: :controller do
  describe "redirects searches with legacy params", solr: false do
    describe "sort" do
      let(:legacy_sort) { "system_create_dtsi desc" }
      let(:new_sort) { "recently_added" }

      let(:legacy_facets) do
        {
          subject_sim: ["subject"],
          rights_sim: ["http://creativecommons.org/publicdomain/mark/1.0/"]
        }
      end
      let(:new_facets) do
        {
          subject_facet: ["subject"],
          rights_facet: ["http://creativecommons.org/publicdomain/mark/1.0/"]
        }
      end

      let(:base_params) { { q: "some search", arbitrary_thing_to_preserve: "value", search_field: "all_fields" } }

      it "redirects" do
        get :index, params: base_params.merge(sort: legacy_sort, f: legacy_facets)
        expect(response).to redirect_to(search_catalog_path(base_params.merge(sort: new_sort, f: new_facets)))
      end
    end
  end
end
