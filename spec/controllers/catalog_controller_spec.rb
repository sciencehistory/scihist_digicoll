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
    around do |example|
      # Temporarily turn off raise-on-unpermitted-param to test production
      # behavior
      original = ActionController::Parameters.action_on_unpermitted_parameters
      ActionController::Parameters.action_on_unpermitted_parameters = false

      example.run

      ActionController::Parameters.action_on_unpermitted_parameters = original
    end

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
      it "ignores" do
        get :index, params: { range: "bad" }
        expect(response).to have_http_status(200)
      end
    end

    # Regression test for issue https://github.com/sciencehistory/scihist_digicoll/issues/2231
    # Normally the values in the range params need to be hash-like,
    # but in this particular case we allow an array.
    describe "blacklight range limit 'date missing'" do
      it "returns http 200" do
        get :index, params: {
        "range" => {
            "-year_facet_isim" => ["[* TO *]"],
            "year_facet_isim"  => { "begin"=>"", "end"=>"" }
          }
        }
        expect(response).to have_http_status(200)
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

      it "ignores" do
        get :index, params: params
        expect(response.status).to eq(200)
      end
    end
  end

  describe "bad URL params passed to range_limit (should not happen under normal use)" do
    around do |example|
      # Temporarily turn off raise-on-unpermitted-param to test production
      # behavior
      original = ActionController::Parameters.action_on_unpermitted_parameters
      ActionController::Parameters.action_on_unpermitted_parameters = false

      example.run

      ActionController::Parameters.action_on_unpermitted_parameters = original
    end

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
    let(:not_strings) do
      {
        "range_field"=>"year_facet_isim",
        "range_start"=>"1931",
        "range_end"=>["1940"]
      }
    end

    it "raises BadReqeust without start param" do
      # turned to an http 400 response by rails
      expect {
        get :range_limit, params: no_start_params
      }.to raise_error(ActionController::BadRequest)
    end
    it "raises BadRequest without end param" do
      # turned to an http 400 response by rails
      expect {
        get :range_limit, params: no_end_params
      }.to raise_error(ActionController::BadRequest)
    end
    it "raises BadRequest if params out of order" do
      # turned to an http 400 response by rails
      expect {
        get :range_limit, params: end_before_start_params
      }.to raise_error(ActionController::BadRequest)
    end
    it "raises BadRequest if one of the params is an array" do
      # turned to an http 400 response by rails
      expect {
        get :range_limit, params: not_strings
      }.to raise_error(ActionController::BadRequest)
    end
  end

  describe "advanced search" do
    it "is explicitly turned off" do
      expect { get :advanced_search }.to raise_error(ActionController::RoutingError)
    end
  end

  describe "autocomplete suggest" do
    it "is explicitly turned off" do
      expect { get :suggest }.to raise_error(ActionController::RoutingError)
    end
  end

  # We do not implement rss / atom / json search results (or plan to implement them).
  # e.g. /catalog.rss
  # e.g. /focus/alchemy.json
  describe "request for rss, atom or json via the format parameter" do
    it "throws 406 when rss format is requested." do

      get :index, params: { "format"=>"rss" }
      expect(response.status).to eq(406)
    end
  end

  describe "#facets for more", solr: true do
    render_views

    let(:response_noko) { Nokogiri::HTML(response.body) }

    let!(:work) do
      # Gah, forget why/how we turn off autoindexing and how to turn it back on,
      # this is good enough.
      create(:public_work,
        subject: ["one", "onetwo", "onethree", "three", "four", "josé"],
      ).tap { |w| w.update_index }
    end

    # making sure we haven't broken the built-in stuff
    it "can fetch facets" do
      get :facet, params: { id: "subject_facet" }

      expect(response_noko).to have_selector("a.facet-select", text: "three")
      expect(response_noko).to have_selector("a.facet-select", text: "three")
      expect(response_noko).to have_selector("a.facet-select", text: "four")
      expect(response_noko).to have_selector("a.facet-select", text: "josé")
    end

    # making sure we haven't broken the built-in stuff
    it "can fetch filtered" do
      get :facet, params: { id: "subject_facet", query_fragment: "one" }

      expect(response_noko).to have_selector("a.facet-select", text: "one")
      expect(response_noko).to have_selector("a.facet-select", text: "onetwo")
      expect(response_noko).to have_selector("a.facet-select", text: "onethree")

      expect(response_noko).not_to have_selector("a.facet-select", exact_text: "three")
    end

    describe "additional custom functionality" do
      describe "normalizes unicode" do
        it "can find with NFC" do
          get :facet, params: { id: "subject_facet", query_fragment: "josé".unicode_normalize(:nfc) }
          expect(response_noko).to have_selector("a.facet-select", text: "josé")
        end

        it "can find with NFD" do
          get :facet, params: { id: "subject_facet", query_fragment: "josé".unicode_normalize(:nfd) }
          expect(response_noko).to have_selector("a.facet-select", text: "josé")
        end
      end

      it "can only find at beginning of words" do
        get :facet, params: { id: "subject_facet", query_fragment: "three" }

        expect(response_noko).to have_selector("a.facet-select", text: "three")

        expect(response_noko).not_to have_selector("a.facet-select", text: "onethree")
      end
    end
  end
end
