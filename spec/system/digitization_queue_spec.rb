require 'rails_helper'

RSpec.describe "Digitization Queue", :logged_in_user, type: :system do
  it "run-through" do
    visit collecting_areas_admin_digitization_queue_items_path

    click_on "Rare Books"

    click_on "New Queue Item"

    fill_in "Title", with: "Test Item"
    fill_in "Accession number", with: "test-acc"
    fill_in "Object ID (Past Perfect)", with: "test-obj-id"
    fill_in "Bib number", with: "b1234567"
    fill_in "Box", with: "test-box"
    fill_in "Folder", with: "test-folder"
    fill_in "Dimensions", with: "test-dimensions"
    fill_in "Materials", with: "test-materials"
    fill_in "Scope", with: "Do this"
    fill_in "Instructions", with: "And this"
    fill_in "Location", with: "Some location"

    click_on "Create Digitization queue item"
    # return to listing page, now click on item we just made

    click_on "Test Item"

    # Now create a work from it
    click_on "Create new attached work"
    click_on "Create Work"

    expect(page).to have_text("Work was successfully created")

    work = Work.order(created_at: :desc).last

    expect(work.title).to eq("Test Item")
    expect(work.digitization_queue_item).to be_present
    expect(work.external_id.find {|i| i.category == "accn" }&.value).to eq("test-acc")
    expect(work.external_id.find {|i| i.category == "object" }&.value).to eq("test-obj-id")
    expect(work.external_id.find {|i| i.category == "bib" }&.value).to eq("b1234567")
    expect(work.physical_container.box).to eq("test-box")
    expect(work.physical_container.folder).to eq("test-folder")
    expect(work.extent).to eq(["test-dimensions"])
    expect(work.medium).to eq(["test-materials"])
  end
end
