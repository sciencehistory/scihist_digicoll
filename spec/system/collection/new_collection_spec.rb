require 'rails_helper'

RSpec.describe "New Collection form", logged_in_user: :editor, type: :system, js: true, queue_adapter: :test do
  it "saves new collection with thumbnail" do
    visit new_admin_collection_path

    fill_in "collection[title]", with: "New collection title"
    select "Archives", :from => "collection[department]"
    fill_in "collection[description]", with: "New collection desc with <script>bad tag</script> and <b>bold</b>"
    fill_in "collection[related_link_attributes][0][url]", with: "http://example.org"
    select "Other internal", from: "collection[related_link_attributes][0][category]"

    # the hidden file input used by uppy, we can target directly...
    add_file_via_uppy_dashboard input_name: "files[]", file_path: (Rails.root + "spec/test_support/images/30x30.png").to_s
    # and make sure we're waiting for uppy to finish...
    expect(page).to have_text("Will be saved: ")

    click_button "Create Collection"

    # Wait for action to complete, and return Collection list page
    expect(page).to have_css("h1", text: "Collections")

    # check data
    newly_added_collection = Collection.order(:created_at).last

    expect(newly_added_collection.title).to eq("New collection title")
    expect(newly_added_collection.description).to eq("New collection desc with bad tag and <b>bold</b>")
    expect(newly_added_collection.related_link).to eq([RelatedLink.new(category: "other_internal", label: "", url:"http://example.org")])

    expect(newly_added_collection.representative).to be_present
    expect(newly_added_collection.representative).to be_kind_of(Asset)
    expect(newly_added_collection.representative.parent).to eq(newly_added_collection)
    expect(Kithe::AssetPromoteJob).to have_been_enqueued
  end

  it "re-shows page keeping file input on validation error", queue_adapter: :test do
    visit new_admin_collection_path

    fill_in "collection[description]", with: "entered description"

    fill_in "collection[related_link_attributes][0][url]", with: "http://example.org"
    select "Other internal", from: "collection[related_link_attributes][0][category]"

    select "Archives", :from => "collection[department]"

    # the hidden file input used by uppy, we can target directly...
    add_file_via_uppy_dashboard input_name: "files[]", file_path: (Rails.root + "spec/test_support/images/30x30.png").to_s
    # wait for it to be uploaded async
    expect(page).to have_text("Will be saved")

    click_button "Create Collection"
    expect(page).to have_text("1 error prohibited this collection from being saved")

    expect(find_field('collection[description]').value).to eq 'entered description'
    expect(find_field("collection[related_link_attributes][0][url]").value).to eq "http://example.org"
    expect(page).to have_text("Will be saved: 30x30.png")

    fill_in "collection[title]", with: "Added collection title"
    click_button "Create Collection"

    expect(page).to have_css("h1", text: "Collections")

    newly_added_collection = Collection.order(:created_at).last
    expect(newly_added_collection.title).to eq("Added collection title")
    expect(newly_added_collection.representative).to be_present
    expect(newly_added_collection.representative.file).to be_present
    expect(newly_added_collection.representative.file.original_filename).to eq("30x30.png")
  end
end
