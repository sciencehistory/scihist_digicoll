require 'rails_helper'
RSpec.describe "Staff user cannot use UI elements that are off limits",
  :logged_in_user, type: :system do
  let(:work) { create(:oral_history_work, :published) }

  it "public work show: no cart link in the top nav" do
    visit work_path(work)
    expect(page).not_to have_link('Cart')
  end

  it "admin works list" do
    title = work.title
    visit admin_works_path
    expect(page).not_to have_link('Cart')
    expect(page).not_to have_link('Users')
    click_on 'Admin' # to see the menu
    disabled_links_text = page.find_all('a.disabled').map {|a| a.text }
    expect(disabled_links_text).to eq  [
      "Create new work",
      "Batch create works",
      "Edit Metadata",
      "Members",
      "Demote to Asset",
      "Delete"
    ]
  end

  it "admin work show" do
    visit admin_work_path(work)

    disabled_links_text = page.find_all('.disabled').map {|a| a.text }
    expect(disabled_links_text).to eq  [
      "Edit Metadata"
    ]

    # Work list members tab
    click_on "Members"
    disabled_links_text = page.find_all('.disabled').map {|a| a.text }
    expect(disabled_links_text).to eq  [
      "Files",
      "New Child Work",
      "Manual",
      "Alphabetical"
    ]

    # OH tab
    click_on "Oral History"
    disabled_labels_text = page.find_all('label.disabled').map {|a| a.text }
    expect(disabled_labels_text).to eq  [
      "Interviewee biographies",
      "Interviewer profiles"
    ]
    expect(page.find_all("input").map {|a| a[:disabled] }.all?).to be true

    # Can't publish
    click_on "Unpublish"
    disabled_links_text = page.find_all('.disabled').map {|a| a.text }
    expect(disabled_links_text).to include("Also unpublish all members")
    expect(disabled_links_text).to include("Leave members as they are")
  end

  it "asset show" do
    visit admin_asset_path(work.members.first)
    expect(page.find_all('input[type="submit"]')[0][:disabled]).to eq "true"
    disabled_links_text = page.find_all('.disabled').map {|a| a.text }
    expect(disabled_links_text).to include("Edit")
    expect(disabled_links_text).to include("Convert to child work")
  end

  it "collections list" do
    visit admin_collections_path
    click_on "Collections"
    disabled_links_text = page.find_all('.disabled').map {|a| a.text }
    expect(disabled_links_text).to include("New Collection")
  end
end