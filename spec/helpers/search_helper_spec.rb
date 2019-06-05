require 'rails_helper'

describe SearchHelper, type: :helper do
  describe "#search_on_facet_path" do
    it "raises for non-defined facet field" do
      expect {
        helper.search_on_facet_path(:non_existing_field, "value")
      }.to raise_error(ArgumentError)
    end

    it "produces a path for good input" do
      facet_field = CatalogController.blacklight_config.facet_fields.keys.first
      result = helper.search_on_facet_path(facet_field, "value")

      expect(result).to eq(search_catalog_path(f: { facet_field => ["value"] }))
    end
  end
end
