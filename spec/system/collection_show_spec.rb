require 'rails_helper'

describe "Collection show page", solr: true, indexable_callbacks: true do
  describe "smoke test" do
    let(:collection) do
      create(:collection,
        description: "some description",
        external_id: [{category: "bib", value: "b9999999"}],
        related_link: [
          RelatedLink.new(category: "finding_aid", url: "http://archives.sciencehistory.org/some/collection"),
          RelatedLink.new(category: "other_internal", url: "https://sciencehistory.org/foo/bar", label: "Article about this")
        ]
      ).tap do |col|
        # doing these as separate creates after collection exists necessary for them to have collection
        # on save, so to get indexed properly
        #
        # Different dates to make sure we exersize blacklight_range_limit a bit.
        create(:public_work, title: "public work one", subject: ["Some subject"], date_of_work: Work::DateOfWork.new(start: "2019"), contained_by: [col])
        create(:public_work, title: "public work two", date_of_work: Work::DateOfWork.new(start: "1900"), contained_by: [col])
        create(:private_work, title: "private work", contained_by: [col])
      end
    end

    it "displays" do
      visit collection_path(collection)

      expect(page).to be_axe_clean

      expect(page).to have_selector("h1", text: collection.title)

      expect(page).to have_content("2 items") # one is not public

      expect(page).to have_content(collection.description)

      expect(page).to have_link(href: "https://othmerlib.sciencehistory.org/record=b9999999", text: /View in library catalog/i)
      expect(page).to have_link(href: "http://archives.sciencehistory.org/some/collection", text: /View Collection guide/i)
      expect(page).to have_link(href: "https://sciencehistory.org/foo/bar", text: "Article about this")

      expect(page).to have_content("public work one")
      expect(page).to have_content("public work two")
      expect(page).not_to have_content("private_work")

      within(".facets") do
        expect(page).to have_selector(:link_or_button, "Date")
        expect(page).to have_selector(:link_or_button, "Genre")
        expect(page).to have_selector(:link_or_button, "Format")
        expect(page).to have_selector(:link_or_button, "Rights")
        expect(page).to have_selector(:link_or_button, "Subject")
      end
    end

    describe "no results" do
      let(:collection) { create(:collection, department: CollectionShowController::ORAL_HISTORY_DEPARTMENT_VALUE) }
      it "displays correct no-results content", js: true, solr: true, indexable_callbacks: true do
        visit collection_path(collection, q: 'abc123')
        expect(page).to have_content("Sorry, we couldn't find any records for your search.")
        expect(page).to have_content("Ever Bumped by Dead Weight?")
      end
    end
  end

  # This broke once when we upgraded BL
  describe "facets and facet more button" do
    let(:collection) do
      create(:collection,
        description: "some description",
        external_id: [{category: "bib", value: "b9999999"}],
      ).tap do |col|
        # doing these as separate creates after collection exists necessary for them to have collection
        # on save, so to get indexed properly
        #
        # Different dates to make sure we exersize blacklight_range_limit a bit.
        create(:public_work,
          title: "public work one",
          subject: 1.upto(100).collect { |i| "Subject #{i}" },
          date_of_work: Work::DateOfWork.new(start: "2019"),
          contained_by: [col]
        )
      end
    end

    it "can access" do
      visit collection_path(collection)

      within(".facets") do
        click_on "Subject"
      end

      within("#facet-subject_facet") do
        find("a", text: /more/).click
      end

      expect(page).to have_selector(".modal-header", text: "Subject")
    end
  end

  describe "generic oral history collection" do
    let(:collection) { create(:collection, department: CollectionShowController::ORAL_HISTORY_DEPARTMENT_VALUE) }
    let!(:oral_history) { create(:oral_history_work, :published, subject: ["Chemistry"], contained_by: [collection]) }

    it "displays custom OH facets", js: false do
      visit collection_path(collection)

      expect(page).to have_content(oral_history.title)

      within(".facets") do
        expect(page).to have_selector(:link_or_button, "Interview Date")
        expect(page).to have_selector(:link_or_button, "Interviewer")
        expect(page).to have_selector(:link_or_button, "Institution")
        expect(page).to have_selector(:link_or_button, "Birth Country")
        expect(page).to have_selector(:link_or_button, "Features")
        expect(page).to have_selector(:link_or_button, "Availability")
        expect(page).to have_selector(:link_or_button, "Subject")

        expect(page).not_to have_selector(:link_or_button, text: /^Date$/)
        expect(page).not_to have_selector(:link_or_button, "Genre")
        expect(page).not_to have_selector(:link_or_button, "Format")
        expect(page).not_to have_selector(:link_or_button, "Rights")
      end
    end
  end

  describe "Exhibiton collection" do
    let(:collection) { create(:collection, department: Collection::DEPARTMENT_EXHIBITION_VALUE) }

    it "displays", js: false do
      visit collection_path(collection)
      expect(page).to have_selector(".show-genre", text: "Exhibitions")
    end
  end

end
