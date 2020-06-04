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
      create(:public_work,
        description: 'priceless work',
        representative: create(:asset, :inline_promoted_file, published: true),
        members: [create(:public_work), create(:public_work)])
    end

    let!(:collection) do
      create(:collection,
        description: 'priceless collection',
        representative: create(:asset, :inline_promoted_file, published: true),
        contains: [work1] )
    end

    # just a smoke test
    it "loads" do
      visit search_catalog_path(search_field: "all_fields")

      expect(page).to have_content("1 - 4 of 4")

      within("#document_#{work1.friendlier_id}") do
        expect(page).to have_content(work1.title)
        expect(page).to have_content(work1.description)
        expect(page).to have_content /2 items/i
        expect(page).to have_selector("img[src='#{work1.leaf_representative.file_url(:thumb_standard)}']")
        expect(page).to have_link(text: work1.title, href: work_path(work1))
      end

      within("#document_#{collection.friendlier_id}") do
        expect(page).to have_content(collection.title)
        expect(page).to have_content(collection.description)
        expect(page).to have_selector("img[src='#{collection.leaf_representative.file_url(:thumb_standard)}']")
        expect(page).to have_content /1 item/i
        #expect(page).to have_link(text: collection.title, href: collection_path(work1))
      end

      # no fulltext search highlights here
      expect(page).not_to have_selector(".scihist-results-list-item-highlights")
    end
  end

  describe "admin notes" do
    let(:admin_note_text) { "an admin note" }
    let(:admin_note_query) { "\"#{admin_note_text}\"" }
    let!(:work_with_admin_note) { create(:public_work, admin_note: admin_note_text) }

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

  describe "navbar search slide-out limits" do
    let(:green_rights) { "http://creativecommons.org/publicdomain/mark/1.0/" }
    let(:red_rights) { "http://rightsstatements.org/vocab/InC/1.0/" }
    let(:green_date) { Work::DateOfWork.new({ "start"=>"2014-01-01"}) }
    let(:green_title) { "good title" }

    let!(:green) { create(:public_work, title: green_title, rights: green_rights, date_of_work: green_date) }
    let!(:red1)  { create(:public_work, title: green_title, rights: green_rights) }
    let!(:red2)  { create(:public_work, title: green_title, date_of_work: green_date, rights: red_rights) }

    it "can use limits to find only matching work" do
      visit search_catalog_path
      fill_in "q", with: green_title
      fill_in "search-option-date-from", with: "2013"
      fill_in "search-option-date-to", with: "2015"
      check("Public Domain Only")
      click_on "Go"

      expect(page).to have_content("1 entry found")
      expect(page).to have_selector("li#document_#{green.friendlier_id}")
      expect(page).not_to have_selector("li#document_#{red1.friendlier_id}")
      expect(page).not_to have_selector("li#document_#{red2.friendlier_id}")
    end
  end

  describe "non-published items" do
    let!(:non_published_work) { create(:private_work, title: "work non-published") }
    let!(:non_published_collection) { create(:private_work, title: "collection non-published") }
    let!(:published_work) { create(:public_work, title: "work published") }

    it "do not show up in search results unless the user is logged in" do
      visit search_catalog_path(search_field: "all_fields")

      expect(page).to have_content(published_work.title)
      expect(page).not_to have_content(non_published_work.title)
      expect(page).not_to have_content(non_published_collection.title)
    end
  end

  describe "non-published items", logged_in_user: true do
    let!(:non_published_work) { create(:private_work, title: "work non-published") }
    let!(:non_published_collection) { create(:private_work, title: "collection non-published") }
    let!(:published_work) { create(:public_work, title: "work published") }

    it "show up in search results if the user is logged in, flagged as private" do
      visit search_catalog_path(search_field: "all_fields")
      expect(page).to have_content(published_work.title)
      expect(page).to have_content(non_published_work.title)
      expect(page).to have_content(non_published_collection.title)
      within("#document_#{published_work.friendlier_id}") do
        expect(page).not_to have_content("Private")
      end
      within("#document_#{non_published_collection.friendlier_id}") do
        expect(page).to have_content("Private")
      end
      within("#document_#{non_published_work.friendlier_id}") do
        expect(page).to have_content("Private")
      end
    end
  end

  describe "transcrpt search highlights" do
    let(:ohms_xml_path) { Rails.root + "spec/test_support/ohms_xml/hanford_OH0139.xml" }
    let!(:published_work) do
      create(:public_work, title: "an oral history", genre: "Oral histories").tap do |work|
        work.oral_history_content!.update(ohms_xml_text: File.read(ohms_xml_path))
        work.update_index
      end
    end

    it "can find and highlight transcript matches" do
      visit search_catalog_path(search_field: "all_fields", q: '"I graduated from Bristol High School"')

      expect(page).to have_selector("#document_#{published_work.friendlier_id}")
      within("#document_#{published_work.friendlier_id}") do
        expect(page).to have_selector(".scihist-results-list-item-highlights em", text: "I graduated from Bristol High School")
      end
    end
  end
end
