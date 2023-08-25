require 'rails_helper'

RSpec.describe "ingest files to work", logged_in_user: :editor, type: :system, js: true, queue_adapter: :test do
  let(:work) { FactoryBot.create(:work) }

  it "can add files" do
    visit admin_asset_ingest_path(work)

    add_file_via_uppy_dashboard(input_name: "files[]", file_path: Rails.root.join("spec/test_support/images/30x30.png"))

    expect(page).to have_css(".attach-files-table td", text: /30x30\.png/)

    expect do
      click_on "Attach"

      expect(page).to have_css("h1", text: work.title)
    end.to change { Asset.count }.by(1).and have_enqueued_job(Kithe::AssetPromoteJob)

    work.reload
    asset = work.members.first
    expect(asset).to be_kind_of(Asset)
    expect(asset.title).to eq("30x30.png")
  end

  it "can add a file with restricted derivative storage", queue_adapter: :inline do
    visit admin_asset_ingest_path(work)

    add_file_via_uppy_dashboard(input_name: "files[]", file_path: Rails.root.join("spec/test_support/images/20x20.png"))

    expect(page).to have_css(".attach-files-table td", text: /20x20\.png/)

    page.find(".derivative-storage-type").find("option", text: "restricted").select_option

    click_on "Attach"

    expect(page).to have_css("h1", text: work.title)

    asset = work.reload.members.first

    expect(asset.file_derivatives.values).to all(satisfy { |d| d.storage_key == :restricted_kithe_derivatives})
  end
end
