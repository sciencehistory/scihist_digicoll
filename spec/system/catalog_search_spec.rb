require 'rails_helper'

# Blacklight-powered search
#
# System tests are slow, and ideally we might be testing more functionality in unit
# tests. But Blacklight sometimes makes it hard to set up unit testing, and I don't totally
# trust that future versions of Blacklight wouldn't break our unit tests assumptions, a
# full integration test on UI is safest and easiest.
describe CatalogController, solr: true, indexable_callbacks: true do
  describe "general smoke test with lots of features", queue_adapter: :inline do
    let!(:work1) do
      create(:public_work,
        description: 'priceless work',
        date_of_work: { start: "2019" },
        subject: ["one", "two", "three", "four", "five", "six"],
        representative: create(:asset, :inline_promoted_file, published: true),
        members: [
          create(:public_work, date_of_work: { start: "2020" }),
          create(:public_work, date_of_work: { start: "2021" })
        ])
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

      expect(page).to be_axe_clean

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

      # Make sure the date facet labels missing dates as "Undated".
      # See https://github.com/sciencehistory/scihist_digicoll/issues/2282
      click_on "Date"
      within "div.blacklight-year_facet_isim" do
        expect(page).to have_content "Undated"

        # requires async JS to load actual chart, but make sure it does show up,
        # along with ranges
        expect(page).to have_selector(".chart-wrapper canvas")
        expect(page).to have_selector("summary", text: "Range List")
      end

      # no fulltext search highlights here
      expect(page).not_to have_selector(".scihist-results-list-item-highlights")

      # Make sure facet "more" works -- Blacklight upgrades have given us regression
      # here before.
      within(".blacklight-subject_facet") do
        click_on "Subject"
        click_on "more"
      end
      expect(page).to have_selector("h1.modal-title", text: "Subject")
    end
  end

  describe "admin notes" do
    let(:admin_note_text) { "an admin note" }
    let(:admin_note_query) { "\"#{admin_note_text}\"" }
    let!(:work_with_admin_note) { create(:public_work, admin_note: admin_note_text) }

    describe "no logged in user" do
      it "can not find admin note" do
        visit search_catalog_path(q: admin_note_query)
        expect(page).to have_content("couldn't find any records for your search")
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
    let(:cc_public_domain) { "http://creativecommons.org/publicdomain/mark/1.0/" }
    let(:no_known_copyright) { "http://rightsstatements.org/vocab/NKC/1.0/" }
    let(:no_copyright_united_states) { "http://rightsstatements.org/vocab/NoC-US/1.0/" }
    let(:no_copyright_other_restrictions) { "http://rightsstatements.org/vocab/NoC-OKLR/1.0/" }

    let(:in_copyright) { "http://rightsstatements.org/vocab/InC/1.0/" }

    let(:matching_date) { Work::DateOfWork.new({ "start"=>"2014-01-01"}) }
    let(:too_recent)    { Work::DateOfWork.new({ "start"=>"2021-01-01"}) }

    let(:title_for_search) { "good title" }

    let!(:published_and_public_domain) { create(:public_work, title: title_for_search, rights: cc_public_domain, date_of_work: matching_date) }
    let!(:published_and_nkc) { create(:public_work, title: title_for_search, rights: no_known_copyright, date_of_work: matching_date) }
    let!(:published_and_no_copyright) { create(:public_work, title: title_for_search, rights: no_copyright_united_states, date_of_work: matching_date) }
    let!(:published_and_nc_other_restrictions) { create(:public_work, title: title_for_search, rights: no_copyright_other_restrictions, date_of_work: matching_date) }

    let!(:published_and_public_domain_but_too_recent) { create(:public_work, title: title_for_search, rights: cc_public_domain, date_of_work: too_recent) }

    let!(:unpublished_but_public_domain)  { create(:public_work, title: title_for_search, rights: cc_public_domain) }
    let!(:published_but_copyrighted)  { create(:public_work, title: title_for_search, date_of_work: matching_date, rights: in_copyright) }

    it "can use limits to find works we consider copyright free" do
      visit search_catalog_path
      fill_in "q", with: title_for_search
      fill_in "search-option-date-from", with: "2013"
      fill_in "search-option-date-to", with: "2015"
      check("Copyright Free Only")
      click_on "Search"

      # 4 results
      expect(page).to have_selector('.scihist-results-list-item', count: 4)

      # these are all considered "copyright free"
      expect(page).to have_selector("li#document_#{published_and_public_domain.friendlier_id}")
      expect(page).to have_selector("li#document_#{published_and_nkc.friendlier_id}")
      expect(page).to have_selector("li#document_#{published_and_no_copyright.friendlier_id}")
      expect(page).to have_selector("li#document_#{published_and_nc_other_restrictions.friendlier_id}")

      # "Rights" facet should already be visible, since it had a selection.
      expect(page).to have_selector('#facet-rights_facet.show', visible: true)

      within(".blacklight-rights_facet") do
        labels = page.find_all('.facet-label', visible:true).map { |label| label.text }
        counts = page.find_all('.facet-count', visible:true).map { |count| count.text.to_i }
        expect(labels.zip(counts).to_h).to eq ({
          "Copyright Free\n[remove]" => 4,
          "Public Domain Mark 1.0" => 1,
          "No Known Copyright" => 1,
          "No Copyright - Other Known Legal Restrictions" => 1,
          "No Copyright - United States" => 1
        })
      end
      # considered in copyright, so should not match the search:
      expect(page).not_to have_selector("li#document_#{unpublished_but_public_domain.friendlier_id}")
      expect(page).not_to have_selector("li#document_#{published_but_copyrighted.friendlier_id}")

      # too recent, so should not match the search:
      expect(page).not_to have_selector("li#document_#{published_and_public_domain_but_too_recent.friendlier_id}")
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

  describe "transcirpt search highlights" do
    let(:ohms_xml_path) { Rails.root + "spec/test_support/ohms_xml/legacy/hanford_OH0139.xml" }
    let!(:published_work) do
      create(:public_work, title: "an oral history", genre: "Oral histories", description: "this is a description").tap do |work|
        work.oral_history_content!.update(ohms_xml_text: File.read(ohms_xml_path))
        work.update_index
      end
    end

    it "can find and highlight transcript matches" do
      visit search_catalog_path(search_field: "all_fields", q: '"I graduated from Bristol High School"')
      expect(page).to have_selector("#document_#{published_work.friendlier_id}")
      within("#document_#{published_work.friendlier_id}") do
        # byebug
        # expect(page).to have_selector(".scihist-results-list-item-highlights em", text: "I graduated from Bristol High School")

        # expect(page).to have_selector(".scihist-results-list-item-highlights em", text: "I")
        # expect(page).to have_selector(".scihist-results-list-item-highlights em", text: "graduated")
        # expect(page).to have_selector(".scihist-results-list-item-highlights em", text: "from")
        # expect(page).to have_selector(".scihist-results-list-item-highlights em", text: "Bristol")
        # expect(page).to have_selector(".scihist-results-list-item-highlights em", text: "High")
        # expect(page).to have_selector(".scihist-results-list-item-highlights em", text: "School")

         "I graduated from Bristol High School".split.each {|word| expect(page).to have_selector(".scihist-results-list-item-highlights em", text: word) }

        expect(page).not_to have_selector(".scihist-results-list-item-description")
        expect(page).not_to have_content(published_work.description)
      end
    end
  end

  describe "text query constraint as search field" do
    let(:title) { "Match on this title" }
    let(:subject) { "Chemistry" }
    let(:year_i) { 1985 }
    let(:year) { year_i.to_s }

    let!(:work1) do
      create(:public_work,
        title: title,
        date_of_work: Work::DateOfWork.new(start: year),
        subject: [subject]
      )
    end

    it "displays search form, and keeps constraints on submit" do
      from_date = (year_i - 10).to_s
      to_date   = (year_i + 10).to_s

      visit search_catalog_path(search_field: "all_fields",
        q: "match",
        range: { year_facet_isim: { begin: from_date, end: to_date } },
        f: { subject_facet: [subject] }
      )

      # now try to change the query in the little search form in customized
      # editable query constraint
      within("form.scihist-constraints-query") do
        fill_in :q, with: title, fill_options: { clear: :backspace } # that fill_options nonsense seems to workaround a capybara bug
        click_on "Go"
      end

      # keeps all the constraints plus has our new one
      within(".constraints-container") do
        expect(page).to have_text(/#{title}/i) # not sure why capybara thinks this was uppercase on page, oh well.
        expect(page).to have_text("Subject #{subject}")
        expect(page).to have_text("Date #{from_date} to #{to_date}")
      end
    end

    it "displays editable search-within form even with no query" do
      visit search_catalog_path(search_field: "all_fields",
        f: { subject_facet: [subject] }
      )

      # We're making sure this form is HERE even though we didn't have an initial query
      within("form.scihist-constraints-query") do
        fill_in :q, with: title, fill_options: { clear: :backspace } # that fill_options nonsense seems to workaround a capybara bug
        click_on "Go"
      end

      # keeps all the constraints plus has our new one
      within(".constraints-container") do
        expect(page).to have_text(/#{title}/i) # not sure why capybara thinks this was uppercase on page, oh well.
        expect(page).to have_text("Subject #{subject}")
      end
    end
  end

  describe "transcriptions and English translations, searchable via two fulltext indices" do
    let(:assets) do
      [ create(:asset,
          transcription:       "Postkarte [stamps] Herr Prof. G. Bredig",
          english_translation: "Postcard [stamps] Prof. G. Bredig"),
        create(:asset,
          transcription:       "Für Ihre Aufmerksamkeit zu meinem Geburtstag danke ich Ihnen.",
          english_translation: "Thank you for wishing me a Happy Birthday.") ]
    end
    let(:works) do
      [['de'], ['de','en'], ['en']].map do |languages|
        create(:public_work, language: languages, members: assets).tap { |work| work.update_index }
      end
    end
    it "shows matches from both full text indices, regardless of work language(s)" do
      works.each do |postcard|

        visit search_catalog_path(search_field: "all_fields", q: '"Birthday"')
        expect(page).to have_selector("#document_#{postcard.friendlier_id}")
        within("#document_#{postcard.friendlier_id}") do
          expect(page).to have_selector(".scihist-results-list-item-highlights em", text: "Birthday")
        end

        visit search_catalog_path(search_field: "all_fields", q: '"Geburtstag"')
        expect(page).to have_selector("#document_#{postcard.friendlier_id}")
        within("#document_#{postcard.friendlier_id}") do
          expect(page).to have_selector(".scihist-results-list-item-highlights em", text: "Geburtstag")
        end

      end
    end
  end

  describe "works with various combinations of published_at and modified_at" do
    let(:days_ago) { (1..6).to_a.map { |i| i.days.ago } }
    let!(:works) do
      [
        create(:public_work).tap do |w|
          w.title = "published_at old"
          w.published_at = days_ago[5]
          w.created_at   = days_ago[5]
          w.save(validate:false)
        end,
        create(:public_work).tap do |w|
          w.title = "published_at medium"
          w.published_at = days_ago[4]
          w.created_at   = days_ago[4]
          w.save(validate:false)
        end,
        create(:public_work).tap do |w|
          w.title = "published_at new, created_at older"
          w.published_at = days_ago[3]
          w.created_at   = days_ago[3]
          w.save(validate:false)
        end,
        create(:public_work).tap do |w|
          w.title = "published_at new, created_at newer"
          w.published_at = days_ago[3]
          w.created_at   = days_ago[2]
          w.save(validate:false)
        end,
        create(:public_work).tap do |w|
          w.title = "published_at nil, created_at older"
          w.published_at = nil
          w.created_at   = days_ago[2]
          w.save(validate:false)
        end,
        create(:public_work).tap do |w|
          w.title = "published_at nil, created_at newer"
          w.published_at = nil
          w.created_at   = days_ago[1]
          w.save(validate:false)
        end
      ]
    end
    it "default search shows them sorted correctly: first by published_at, then by created_at" do
      visit search_catalog_path(search_field: "all_fields")
      titles_in_order =  page.find_all('.scihist-results-list-item-content h2 a').map {|link| link.text}
      expect(titles_in_order).to eq [
        "published_at new, created_at newer",
        "published_at new, created_at older",
        "published_at medium",
        "published_at old",
        "published_at nil, created_at newer",
        "published_at nil, created_at older"
      ]
    end
  end
end
