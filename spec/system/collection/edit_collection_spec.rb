require 'rails_helper'

RSpec.describe "Edit Collection form", :logged_in_user, type: :system, queue_adapter: :inline, js: true do
  let(:collection) {
    FactoryBot.create(
        :collection,
        representative: FactoryBot.create(:asset,
                                          :inline_promoted_file,
                                          file: File.open((Rails.root + "spec/test_support/images/30x30.png"))) )
  }

  scenario "edits collection and changes thumbnail" do
    collection.reload
    original_asset = collection.representative
    original_file  = original_asset.file
    expect(original_file.exists?).to be(true)

    visit edit_admin_collection_path(collection)

    fill_in "collection[title]", with: "Edited collection title"
    fill_in "collection[description]", with: "Edited collection desc"

    select "Finding aid", from:"collection[related_link_attributes][0][category]"
    fill_in "collection[related_link_attributes][0][url]", with: "http://example.org/edited"
    fill_in "collection[related_link_attributes][0][label]", with: "edited label"

    select "Sierra Bib No", from: "collection[external_id_attributes][0][category]"
    fill_in "collection[external_id_attributes][0][value]", with: "b1234567"

    # # the hidden file input used by uppy, we can target directly...
    add_file_via_uppy_dashboard input_name: "files[]", file_path: (Rails.root + "spec/test_support/images/20x20.png").to_s
    expect(page).to have_text("Will be saved") # wait for direct upload to complete

    click_on "Update Collection"

    # # Wait for action to complete, and return Collection list page
    expect(page).to have_css("h1", text: "Collections")

    # check data
    collection.reload
    expect(collection.representative).to eq(original_asset) # re-use asset
    expect(collection.representative.file).to be_present
    expect(collection.representative.file).not_to eq(original_file)
    expect(original_file.exists?).to be(false) # has been deleted
    expect(collection.external_id).to eq([Work::ExternalId.new("value"=>"b1234567", "category"=>"bib")])
  end
end
