require 'rails_helper'

RSpec.describe "Digitization Queue", :logged_in_user, type: :system, js: true do
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




    ######
    ######
    # Here we insert a convenient if awkward sub-test
    # to check our status-change dropdown.
    #
    # Note that the dropdown is used with both
    # digitization_queue_items_controller and
    # the r_and_r_items_controller. This tests
    # only the former; it  may be thus be necessary
    # to add more front-end tests to ensure
    # the dropdown interacts correctly with the latter.
    #
    #
    # START STATUS CHANGE AJAX TEST:

    dq  = Admin::DigitizationQueueItem.order(created_at: :desc).last

    # Change the status of the DQ item via the dropdown:
    expect(dq.status).to eq("awaiting_dig_on_cart")
    expect(page).not_to have_selector :css, '.fa-spinner'
    select 'Imaging in process', from: 'admin_digitization_queue_item_status'
    click_button('Save')
    # Wait for the request to come back and the spinner to stop...
    expect(page).not_to have_selector :css, '.fa-spinner'
    dq.reload
    expect(dq.status).to eq("imaging_in_process")
    # OK. If you get here, the dropdown is working in
    # the normal case.


    # An unlikely case, but it has occurred:
    # Ensure an error is thrown when you try
    # to change of an item which is not valid.
    # Make dq invalid by removing its title.
    dq.title = nil
    dq.save!(:validate => false)
    expect(dq.valid?).to be false

    # Now attempt to change its status, which should fail with a JS
    # alert.
    # This block will throw a Selenium::WebDriver::Error::TimeOutError
    # unless the JS alert that we expect occurs.
    accept_alert do
      select 'Batch metadata completed', from: 'admin_digitization_queue_item_status'
      click_button('Save')
    end

    # The item should remain unchanged.
    expect(dq.status).to eq("imaging_in_process")

    # Resume our test.
    dq.title = "Test Item"
    dq.save!
    expect(dq.valid?).to be true


    # END STATUS CHANGE MENU TEST
    ######
    ######

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
