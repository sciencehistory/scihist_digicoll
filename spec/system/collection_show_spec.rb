require 'rails_helper'

describe "Collection show page", solr: true, indexable_callbacks: true do
  describe "smoke test" do
    let(:collection) do
      create(:collection,
        description: "some description",
        related_url: ["http://othmerlib.sciencehistory.org/record=b1234567", "https://example.org/foo/bar"],
        contains: [create(:work), create(:work), create(:work, published: false)])
    end

    it "displays" do
      visit collection_path(collection)

      expect(page).to have_selector("h1", text: collection.title)

      expect(page).to have_content("2 items") # one is not public

      expect(page).to have_content(collection.description)

      expect(page).to have_link(href: "http://othmerlib.sciencehistory.org/record=b1234567", text: "View in library catalog")
      expect(page).to have_link(href: "https://example.org/foo/bar", text: "example.org/…")
    end
  end
end
