require 'rails_helper'

RSpec.describe "batch create", type: :system, js: true, queue_adapter: :test do
  it "can go through all steps of batch create" do
    visit admin_batch_create_path

    all("select[name='work[external_id_attributes][0][category]'] option")[1].select_option
    fill_in "work[external_id_attributes][0][value]", with: "some_id"

    click_link("Add another Additional title")
    all("input[type=text][name='work[additional_title_attributes][]']").each_with_index do |item, i|
      item.fill_in with: "additional title #{i}"
    end

    click_on "Proceed to Select Files"

    expect(page).to have_css("h1", text: "Select files for batch create")


    # the hidden file input used by uppy, we can target directly...
    attach_file "files[]", (Rails.root + "spec/test_support/images/30x30.png").to_s, make_visible: true
    attach_file "files[]", (Rails.root + "spec/test_support/images/20x20.png").to_s, make_visible: true

    expect(page).to have_css(".attach-files-table td", text: /30x30\.png/)
    expect(page).to have_css(".attach-files-table td", text: /20x20\.png/)

    expect do
      click_on "Attach"

      expect(page).to have_css("h1", text: "Works")
    end.to change { Asset.count }.by(2).
      and change { Work.count }.by(2).
      and have_enqueued_job(Kithe::AssetPromoteJob).exactly(2).times

    new_works = Work.order(created_at: :desc).limit(2).to_a

    expect(new_works.all? do |w|
      w.external_id.first.value == "some_id"
      w.additional_title = ["additional title 0", "additional title 1"]
    end).to be(true)

    expect(new_works.collect(&:title)).to match(["30x30.png", "20x20.png"])
  end
end
