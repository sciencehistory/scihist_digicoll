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

  # See more at bad_blacklight_requests_spec.rb
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

    describe "f param as string" do
      it "returns http 400" do
        get :index, params: { f: "bad" }
        expect(response).to have_http_status(400)
      end
    end

    describe "range param as string" do
      it "returns http 400" do
        get :index, params: { range: "bad" }
        expect(response).to have_http_status(400)
      end
    end

    describe "range value out of order" do
      render_views

      let(:out_of_order_range_params) do
        {
          range: {
            year_facet_isim: {
              begin: "2010",
              end: "2000"
            }
          }
        }
      end

      it "treats as if ordered properly" do
        get :index, params: out_of_order_range_params
        expect(response.status).to eq(200)
        expect(response.body).to include("2000 to 2010")
      end
    end

    describe "empty range param", solr: false do
      let(:params) { { "range" => { "year_facet_isim" => nil } } }

      it "responds with 400" do
        get :index, params: params
        expect(response.status).to eq(400)
      end
    end
  end

  describe "bad URL params passed to range_limit (should not happen under normal use)" do
    let(:no_start_params) do
      {
        "range_field"=>"year_facet_isim",
        "range_start"=>"1931"
      }
    end
    let(:no_end_params) do
      {
        "range_field"=>"year_facet_isim",
        "range_start"=>"1931"
      }
    end
    let(:end_before_start_params) do
      {
        "range_field"=>"year_facet_isim",
        "range_start"=>"1940",
        "range_end"=>"1930"
      }
    end
    it "throws 406 unless start param is present" do
      get :range_limit, params: no_start_params
      expect(response.status).to eq(406)
    end
    it "throws 406 unless end param is present" do
      get :range_limit, params: no_end_params
      expect(response.status).to eq(406)
    end
    it "throws 406 if params out of order" do
      get :range_limit, params: end_before_start_params
      expect(response.status).to eq(406)
    end
  end
end
