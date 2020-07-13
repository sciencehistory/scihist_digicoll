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

  describe "malformed URL params" do
    describe "facet values as Hash" do
      render_views

      let(:malformed_facet_param) do
        { f: { subject_facet: { "0" => "subject1", "1" => "subject2"}, author_facet:  ["author1", "author2"]} }
      end

      let(:corrected_facet_param) do
        { f: { subject_facet: ["subject1", "subject2"], author_facet:  ["author1", "author2"]} }
      end

      it "redirects to be interprted properly" do
        get :index, params: malformed_facet_param
        expect(response).to redirect_to(search_catalog_url(corrected_facet_param))
      end
    end
  end
end
