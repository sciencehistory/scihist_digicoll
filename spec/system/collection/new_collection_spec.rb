require 'rails_helper'

RSpec.describe "New Collection form", js: true do
  scenario "save, edit, and re-save new work" do
    visit new_admin_collection_path

    fill_in "collection[title]", with: "New collection title"
    fill_in "collection[description]", with: "New collection desc with <script>bad tag</script> and <b>bold</b>"
    fill_in "collection[related_url_attributes][]", with: "http://example.org"

    click_button "Create Collection"

    # Wait for action to complete, and return Collection list page
    expect(page).to have_css("h1", text: "Collections")

    # check data
    newly_added_collection = Collection.order(:created_at).last

    expect(newly_added_collection.title).to eq("New collection title")
    expect(newly_added_collection.description).to eq("New collection desc with bad tag and <b>bold</b>")
    expect(newly_added_collection.related_url).to eq(["http://example.org"])
  end
end
