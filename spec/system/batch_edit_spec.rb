# batch edit is weird enough we really do want to test it with a front-end browser
# spec

require 'rails_helper'

describe "Cart and Batch Edit", solr: true, indexable_callbacks: true, logged_in_user: true do
  let!(:work1) {
    create(:work,
      provenance: "provenance 1",
      description: "description 1",
      additional_title: ["additional title 1a", "additional title 1b"],
      creator: [{category: "contributor", value: "creator 1"}])
  }
  let!(:work2) {
    create(:work,
      provenance: "provenance 2",
      description: "description 2",
      additional_title: ["additional title 2a", "additional title 2b"],
      creator: [{category: "contributor", value: "creator 2"}])
  }

  it "smoke test" do
    visit search_catalog_path(search_field: "all_fields")

    # Mark checkbox for cart for both
    find("#cartToggle-#{work1.friendlier_id}").check
    find("#cartToggle-#{work2.friendlier_id}").check

    expect(page).to have_selector("[data-role='cart-counter']", text: 2)
    click_on("2 Cart")

    # Cart Page
    expect(page).to have_selector("h1", text: "Admin Cart")
    click_on("Batch Edit")

    # Batch Update Form
    all("fieldset.work_additional_title input[type=text]")[0].
      fill_in with: "batch edit additional title"
    fill_in "work[provenance]", with: "batch edit provenance"
    click_on("Update 2 Works")

    expect(page).to have_selector("h1", text: "Admin Cart")

    # check changes were made, and non-expected changes were not made
    work1.reload
    work2.reload

    expect(work1.additional_title).to eq(["additional title 1a", "additional title 1b", "batch edit additional title"])
    expect(work1.provenance).to eq "batch edit provenance"
    expect(work1.creator).to eq([Work::Creator.new(category: "contributor", value: "creator 1")])
    expect(work1.description).to eq "description 1"

    expect(work2.additional_title).to eq(["additional title 2a", "additional title 2b", "batch edit additional title"])
    expect(work2.provenance).to eq "batch edit provenance"
    expect(work2.creator).to eq([Work::Creator.new(category: "contributor", value: "creator 2")])
    expect(work2.description).to eq "description 2"
  end
end
