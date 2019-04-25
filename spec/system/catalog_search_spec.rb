require 'rails_helper'

# Blacklight-powered search
describe CatalogController, solr: true, indexable_callbacks: true do
  let!(:work1) { create(:work) }
  let!(:work2) { create(:work) }
  let!(:collection) { create(:collection) }


  # just a smoke test
  it "loads" do
    visit search_catalog_path(search_field: "all_fields")

    expect(page).to have_content("1 - 3 of 3")
    expect(page).to have_content(work1.title)
    expect(page).to have_content(work2.title)
    expect(page).to have_content(collection.title)
  end
end
