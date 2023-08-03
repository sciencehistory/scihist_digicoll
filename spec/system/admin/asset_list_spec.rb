require 'rails_helper'
RSpec.describe "Oral History Access Interviewee bio", :logged_in_user, type: :system, queue_adapter: :test  do
  let!(:normal_asset) { create(:asset, title: "normal asset", parent: create(:work, title: "Parent work")) }
  let!(:orphaned_asset) { create(:asset, title: "orphaned asset", parent: nil) }

  it "can display assets, including orphaned" do
    visit admin_assets_path

    expect(page).to have_text("Assets")

    expect(page).to have_link(normal_asset.title, href: admin_asset_path(normal_asset))
    expect(page).to have_link(normal_asset.parent.title, href: admin_work_path(normal_asset.parent))

    expect(page).to have_link(orphaned_asset.title, href: admin_asset_path(orphaned_asset))
    expect(page).to have_text("NO PARENT")
  end
end
