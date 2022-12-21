require 'rails_helper'
RSpec.describe "Staff user", :logged_in_user, type: :system, queue_adapter: :test  do
  let!(:work) { create(:oral_history_work, :published) }

  it "UI elements that staff users can't use are visible, but turned off" do
    visit admin_works_path

    # Admin navigation
    expect(page).not_to have_link('Users')
    expect(page).not_to have_link('Cart')

    # Works list page
    click_on "Admin"
    disabled_links_text = page.find_all('a.disabled').map {|a| a.text }
    expect(disabled_links_text).to eq  [
      "Create new work",
      "Batch create works",
      "Edit Metadata",
      "Members",
      "Demote to Asset",
      "Delete"
    ]

    # Work show page
    click_on "Oral history interview with William John Bailey"
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

    # Asset show page
    click_on "Assets"
    click_on "Test title"
    expect(page.find_all('input[type="submit"]')[0][:disabled]).to eq "true"
    disabled_links_text = page.find_all('.disabled').map {|a| a.text }
    expect(disabled_links_text).to include("Edit")
    expect(disabled_links_text).to include("Convert to child work")

    # Collections list
    click_on "Collections"
    disabled_links_text = page.find_all('.disabled').map {|a| a.text }
    expect(disabled_links_text).to include("New Collection")
  end
end