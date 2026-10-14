require 'rails_helper'

describe "Batch replace metadata form", type: :system, js: true do
  let(:user) { create(:editor_user) }
  let!(:work) { create(:work, genre: ["Prints", "Engravings"], description: "a widget") }

  before do
    user.works_in_cart << work
    sign_in user
  end

  it "uses select menus for controlled-list attributes, text inputs otherwise, and submits the chosen values" do
    visit admin_batch_replace_metadata_path

    expect(page).to have_field("old_value", type: "text")

    select "Description", from: "field_name"
    expect(page).to have_field("old_value", type: "text")
    expect(page).to have_field("new_value", type: "text")

    select "Genre", from: "field_name"
    expect(page).to have_select("old_value", with_options: ["Prints", "Engravings"])
    expect(page).to have_select("new_value", with_options: ["Prints", "Engravings"])
    select "Engravings", from: "old_value"
    select "Prints", from: "new_value"

    click_button "Preview"

    expect(page).to have_content("1 out of 1 Work in your Cart will be affected")
    expect(page).to have_link(work.title)
  end
end
