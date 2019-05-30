require 'rails_helper'

# Blacklight-powered search
#
# System tests are slow, and ideally we might be testing more functionality in unit
# tests. But Blacklight sometimes makes it hard to set up unit testing, and I don't totally
# trust that future versions of Blacklight wouldn't break our unit tests assumptions, a
# full integration test on UI is safest and easiest.
describe CatalogController, solr: true, indexable_callbacks: true do
  let(:admin_note_text) { "an admin note" }
  let(:admin_note_query) { "\"#{admin_note_text}\"" }
  let!(:work1) { create(:work) }
  let!(:collection) { create(:collection) }
  let!(:work_with_admin_note) { create(:work, admin_note: admin_note_text) }

  # Creating real representatives with derivatives is a bit slow, only do it for our own
  # smoke test.
  describe "with real representative with derivatives" do
    let!(:work1) do
      create(:work,
        representative: create(:asset, :inline_promoted_file),
        members: [create(:work), create(:work)])
    end

    let!(:collection) do
      create(:collection,
        representative: create(:asset, :inline_promoted_file),
        contains: [work1] )
    end

    # just a smoke test
    it "loads" do
      visit search_catalog_path(search_field: "all_fields")

      expect(page).to have_content("1 - 5 of 5")
      expect(page).to have_content(work1.title)
      expect(page).to have_content(work_with_admin_note.title)
      expect(page).to have_content(collection.title)

      # thumbs for work and collection
      expect(page).to have_selector("img[src='#{work1.leaf_representative.derivative_for(:thumb_standard).url}']")
      expect(page).to have_selector("img[src='#{collection.leaf_representative.derivative_for(:thumb_standard).url}']")

      # cheesy check for "Num items", not distinguishing in test which is work and which is collection
      expect(page).to have_content("1 item")
      expect(page).to have_content("2 items")
    end
  end

  it "does not find admin note" do
    visit search_catalog_path(q: admin_note_query)
    expect(page).to have_content("No results found")
  end

  describe "with logged in user", logged_in_user: true do
    it "can find admin note" do
      visit search_catalog_path(q: admin_note_query)
      expect(page).to have_content("1 entry found")
    end
  end
end
