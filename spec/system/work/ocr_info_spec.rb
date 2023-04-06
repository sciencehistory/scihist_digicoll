require 'rails_helper'

describe "Member list displays OCR info", logged_in_user: :editor do
  let(:image_asset_without_hocr) { create(:asset_with_faked_file, title: "No OCR", position: 1) }
  let(:image_asset_with_hocr)    { create(:asset_with_faked_file, title: "Has OCR", hocr: "This is the HOCR", position: 2) }
  let(:sound_asset) { create(:asset_with_faked_file, :m4a, title: "Sound file", position: 3 ) }
  let(:child_work)  { create(:public_work, representative: create(:asset_with_faked_file), title: "Child work", position: 4) }

  let(:work) do
    create(:public_work,
      language: 'en',
      ocr_requested: true,
      members: [ image_asset_without_hocr, image_asset_with_hocr, sound_asset, child_work]
    )
  end

  describe "Work with OCR requested" do
    it "Summarizes assets with OCR correctly; displays show OCR button" do
      visit admin_work_path(work)
      click_on "Members"
      expect(page).to have_text("OCR has been requested for this work.")
      expect(page).to have_text("1 out of 3 assets currently have OCR.")

      path_to_ocr = admin_asset_path(image_asset_with_hocr, anchor: "ocr")
      expect(page.find_all('table.member-list a.ocr-link').count).to eq 1
      expect(page).to have_link(:href=>path_to_ocr)
    end
  end
end
