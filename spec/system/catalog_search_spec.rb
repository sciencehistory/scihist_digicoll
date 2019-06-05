require 'rails_helper'

# Blacklight-powered search
#
# System tests are slow, and ideally we might be testing more functionality in unit
# tests. But Blacklight sometimes makes it hard to set up unit testing, and I don't totally
# trust that future versions of Blacklight wouldn't break our unit tests assumptions, a
# full integration test on UI is safest and easiest.
describe CatalogController, solr: true, indexable_callbacks: true do
  describe "general smoke test with lots of features" do
    let!(:work1) do
      create(:work,
        description: 'priceless work',
        representative: create(:asset, :inline_promoted_file),
        members: [create(:work), create(:work)])
    end

    let!(:collection) do
      create(:collection,
        description: 'priceless collection',
        representative: create(:asset, :inline_promoted_file),
        contains: [work1] )
    end

    # just a smoke test
    it "loads" do
      visit search_catalog_path(search_field: "all_fields")

      expect(page).to have_content("1 - 4 of 4")

      within("#document_#{work1.friendlier_id}") do
        expect(page).to have_content(work1.title)
        expect(page).to have_content(work1.description)
        expect(page).to have_content("2 items")
        expect(page).to have_selector("img[src='#{work1.leaf_representative.derivative_for(:thumb_standard).url}']")
      end

      within("#document_#{collection.friendlier_id}") do
        expect(page).to have_content(collection.title)
        expect(page).to have_content(collection.description)
        expect(page).to have_selector("img[src='#{collection.leaf_representative.derivative_for(:thumb_standard).url}']")
        expect(page).to have_content("1 item")
      end
    end
  end

  describe "admin notes" do
    let(:admin_note_text) { "an admin note" }
    let(:admin_note_query) { "\"#{admin_note_text}\"" }
    let!(:work_with_admin_note) { create(:work, admin_note: admin_note_text) }

    describe "no logged in user" do
      it "can not find admin note" do
        visit search_catalog_path(q: admin_note_query)
        expect(page).to have_content("No results found")
      end
    end

    describe "with logged in user", logged_in_user: true do
      it "can find admin note" do
        visit search_catalog_path(q: admin_note_query)
        expect(page).to have_content("1 entry found")
      end
    end
  end
end
