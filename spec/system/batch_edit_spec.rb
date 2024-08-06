# batch edit is weird enough we really do want to test it with a front-end browser
# spec

require 'rails_helper'

describe "Cart and Batch Edit", solr: true, indexable_callbacks: true, logged_in_user: :editor do

  let!(:collection_1) { FactoryBot.create(:collection, title: "collection_1") }
  let!(:collection_2) { FactoryBot.create(:collection, title: "collection_2") }

  let!(:work0) { create(:work, provenance: "provenance 0")}
  let!(:work1) {
    create(:work,
      title: "w1",
      provenance: "provenance 1",
      description: "description 1",
      additional_title: ["additional title 1a", "additional title 1b"],
      creator: [{category: "contributor", value: "creator 1"}],
      contained_by: [collection_1])
  }
  let!(:work2) {
    create(:work,
      title: "w2",
      provenance: "provenance 2",
      description: "description 2",
      additional_title: ["additional title 2a", "additional title 2b"],
      creator: [{category: "contributor", value: "creator 2"}])
  }
  let!(:work3) {
    create(:work,
      title: "w3",
      contained_by: [collection_2])
  }

  it "smoke test" do

    # Admin works page

    visit admin_works_path


    # Check all items
    find("#check-or-uncheck-all-works").check

    # Remove this line at your own risk.
    stall =  [work0, work1, work2, work3,].map {|w| find("#cartToggle-#{w.friendlier_id}").checked?}

    # Ensure all items get checked
    expect(find("#cartToggle-#{work0.friendlier_id}").checked?).to eq true
    expect(find("#cartToggle-#{work1.friendlier_id}").checked?).to eq true
    expect(find("#cartToggle-#{work2.friendlier_id}").checked?).to eq true
    expect(find("#cartToggle-#{work3.friendlier_id}").checked?).to eq true

    # Ensure the total jumps to 4
    expect(page).to have_selector("[data-role='cart-counter']", text: 4)

    # Uncheck all items
    find("#check-or-uncheck-all-works").uncheck

    # Remove this line at your own risk.
    stall =  [work0, work1, work2, work3,].map {|w| find("#cartToggle-#{w.friendlier_id}").checked?}

    # Ensure all items get unchecked
    expect(find("#cartToggle-#{work0.friendlier_id}").checked?).to eq false
    expect(find("#cartToggle-#{work1.friendlier_id}").checked?).to eq false
    expect(find("#cartToggle-#{work2.friendlier_id}").checked?).to eq false
    expect(find("#cartToggle-#{work3.friendlier_id}").checked?).to eq false


    # Ensure the total jumps to 0
    expect(page).to have_selector("[data-role='cart-counter']", text: 0)


    # Search results page
    visit search_catalog_path(search_field: "all_fields")

    # Mark checkbox for cart for both
    find("#cartToggle-#{work1.friendlier_id}").check
    find("#cartToggle-#{work2.friendlier_id}").check
    find("#cartToggle-#{work3.friendlier_id}").check

    expect(page).to have_selector("[data-role='cart-counter']", text: 3)
    click_on("3 Cart")

    # Cart Page
    expect(page).to have_selector("h1", text: "Admin Cart")
    click_on("Batch Edit")

    within find(".admin-nav") do
      find_link('Cart')
    end

    # Batch Update Form
    expect(page).to have_selector("h1", text: /Batch Edit/)

    # First try an intentional validation error and then fix it
    all("fieldset.work_external_id input[type=text]")[0].
      fill_in with: "id with no category"
    click_on("Update 3 Works")
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

    click_on("Update 3 Works")

    # Back to cart
    expect(page).to have_selector("h1", text: "Admin Cart")

    # check changes were made, and non-expected changes were not made
    work0.reload
    work1.reload
    work2.reload
    work3.reload

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
    # Work 2 didn't have collection_1, so it should be added.
    expect(work2.contained_by.map(&:title)).to eq ["collection_1"]

    # Old collection affiliations are not overwritten, just added to.
    expect(work3.contained_by.map(&:title).sort).to eq ["collection_1", "collection_2"]
  end
end
