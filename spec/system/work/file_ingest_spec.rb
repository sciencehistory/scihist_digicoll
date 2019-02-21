require 'rails_helper'

RSpec.describe "ingest files to work", :logged_in_user, type: :system, js: true, queue_adapter: :test do
  let(:work) { FactoryBot.create(:work) }

  it "can add files" do
    visit admin_asset_ingest_path(work)

    # the hidden file input used by uppy, we can target directly...
    attach_file "files[]", (Rails.root + "spec/test_support/images/30x30.png").to_s, make_visible: true

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
end
