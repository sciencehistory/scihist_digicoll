require 'rails_helper'
describe CatalogController, type: :request, solr: true, queue_adapter: :test, indexable_callbacks: true do
  it "returns a 406 Not Acceptable if you request json" do
    get search_catalog_path(), :headers => { "accept" => "application/json" }
    expect(response.code).to eq "406"
  end

  describe "legacy filters in URL params" do
    it "redirects &filter_public_domain=1" do
      get search_catalog_path("filter_public_domain": "1")

      expect(response).to redirect_to(search_catalog_path(f: { rights_facet: ["http://creativecommons.org/publicdomain/mark/1.0/"]}))
    end

    it "redirects &filter_copyright_free=1" do
      get search_catalog_path("filter_copyright_free": "1")

      expect(response).to redirect_to(search_catalog_path(f: { rights_facet: ["Copyright Free"]}))
    end
  end
end
