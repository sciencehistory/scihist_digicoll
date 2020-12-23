require 'rails_helper'
describe CatalogController, type: :request, solr: true, queue_adapter: :test, indexable_callbacks: true do
  describe "blacklight controller" do
    it "returns a 406 Not Acceptable if you request json" do
      get search_catalog_path(), :headers => { "accept" => "application/json" }
      expect(response.code).to eq "406"
    end
  end
end