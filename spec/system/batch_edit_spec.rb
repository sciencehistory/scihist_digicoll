# batch edit is weird enough we really do want to test it with a front-end browser
# spec

require 'rails_helper'

describe "Cart and Batch Edit", solr: true, indexable_callbacks: true, logged_in_user: true do

  let!(:collection_1) { FactoryBot.create(:collection, title: "collection_1") }
  let!(:collection_2) { FactoryBot.create(:collection, title: "collection_2") }

  let!(:work1) {
    create(:work,
      provenance: "provenance 1",
      description: "description 1",
      additional_title: ["additional title 1a", "additional title 1b"],
      creator: [{category: "contributor", value: "creator 1"}],
      contained_by: [collection_1])
  }
  let!(:work2) {
    create(:work,
      provenance: "provenance 2",
      description: "description 2",
      additional_title: ["additional title 2a", "additional title 2b"],
      creator: [{category: "contributor", value: "creator 2"}])
  }
  let!(:work0) { create(:work, provenance: "provenance 0")}

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
    expect(page).to have_selector("h1", text: /Batch Edit/)

    # First try an intentional validation error and then fix it
    all("fieldset.work_external_id input[type=text]")[0].
      fill_in with: "id with no category"
    click_on("Update 2 Works")
    expect(page).to have_selector("h1", text: /Batch Edit/)
    expect(page).to have_text("External ID is invalid")
    expect(page).to have_text("Category can't be blank")
    # blank it out again
    all("fieldset.work_external_id input[type=text]")[0].
      fill_in with: ""

    # Add a collection:
    all("div.work_contained_by input")[0].fill_in with: "collection_1\n"

    # Now data that is good that we'll really save....
    all("fieldset.work_additional_title input[type=text]")[0].
      fill_in with: "batch edit additional title"
    fill_in "work[provenance]", with: "batch edit provenance"
    click_on("Update 2 Works")

    # Back to cart
    expect(page).to have_selector("h1", text: "Admin Cart")

    # check changes were made, and non-expected changes were not made
    work0.reload
    work1.reload
    work2.reload

    # work0 is unchanged
    expect(work0.provenance).to eq "provenance 0"
    expect(work0.contained_by.map(&:title)).to eq []


    expect(work1.additional_title).to eq(["additional title 1a", "additional title 1b", "batch edit additional title"])
    expect(work1.provenance).to eq "batch edit provenance"
    expect(work1.creator).to eq([Work::Creator.new(category: "contributor", value: "creator 1")])
    expect(work1.description).to eq "description 1"
    # Work 1 was already in collection 1: this batch edit should not change that.
    expect(work1.contained_by.map(&:title)).to eq ["collection_1"]

    expect(work2.additional_title).to eq(["additional title 2a", "additional title 2b", "batch edit additional title"])
    expect(work2.provenance).to eq "batch edit provenance"
    expect(work2.creator).to eq([Work::Creator.new(category: "contributor", value: "creator 2")])
    expect(work2.description).to eq "description 2"
    # Work 2 should have collection 1 added to it.
    expect(work2.contained_by.first.title).to eq "collection_1"

    # Go back to add collection 2 to both works:
    click_on("Batch Edit")
    expect(page).to have_selector("h1", text: /Batch Edit/)
    all("div.work_contained_by input")[0].fill_in with: "collection_2\n"
    click_on("Update 2 Works")

    work0.reload
    work1.reload
    work2.reload
    # Old collection affiliations are not overwritten, just added to.
    # Both collections should now contain both works.
    expect(work0.contained_by.map(&:title)).to eq []
    expect(work1.contained_by.map(&:title)).to eq ["collection_1", "collection_2"]
    expect(work2.contained_by.map(&:title)).to eq ["collection_1", "collection_2"]

  end
end
