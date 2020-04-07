require 'rails_helper'

describe "Collection show page", solr: true, indexable_callbacks: true do
  describe "smoke test" do
    let(:collection) do
      create(:collection,
        description: "some description",
        related_url: ["http://othmerlib.sciencehistory.org/record=b1234567", "https://example.org/foo/bar"]
      ).tap do |col|
        # doing these as separate creates after collection exists necessary for them to have collection
        # on save, so to get indexed properly
        #
        # Different dates to make sure we exersize blacklight_range_limit a bit.
        create(:public_work, title: "public work one", date_of_work: Work::DateOfWork.new(start: "2019"), contained_by: [col])
        create(:public_work, title: "public work two", date_of_work: Work::DateOfWork.new(start: "1900"), contained_by: [col])
        create(:private_work, title: "private work", contained_by: [col])
      end
    end

    it "displays" do
      visit collection_path(collection)

      expect(page).to have_selector("h1", text: collection.title)

      expect(page).to have_content("2 items") # one is not public

      expect(page).to have_content(collection.description)

      expect(page).to have_link(href: "http://othmerlib.sciencehistory.org/record=b1234567", text: "View in library catalog")
      expect(page).to have_link(href: "https://example.org/foo/bar", text: "example.org/…")

      expect(page).to have_content("public work one")
      expect(page).to have_content("public work two")
      expect(page).not_to have_content("private_work")
    end
  end
end
