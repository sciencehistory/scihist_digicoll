require 'rails_helper'

describe "Member list displays OCR info", logged_in_user: :editor do
  let(:image_asset_without_hocr)   { create(:asset_with_faked_file, title: "No OCR", position: 1) }
  let(:image_asset_with_null_hocr) { create(:asset_with_faked_file, title: "Nil OCR", hocr: nil, position: 2) }
  let(:image_asset_with_hocr)      { create(:asset_with_faked_file, title: "Has OCR", hocr: "This is the HOCR", position: 3) }
  let(:image_asset_with_hocr)      { create(:asset_with_faked_file, title: "Has OCR", hocr: "This is the HOCR", position: 4) }
  let(:image_asset_with_ocr_suppressed) { create(:asset_with_faked_file, :suppress_ocr, title: "Asset with OCR suppressed", position: 5) }

  let(:sound_asset) { create(:asset_with_faked_file, :m4a, title: "Sound file", position: 4 ) }
  let(:child_work)  { create(:public_work, representative: create(:asset_with_faked_file), title: "Child work", position: 1) }

  let(:work) do
    create(:public_work,
      language: 'en',
      ocr_requested: true,
      members: [ image_asset_without_hocr, image_asset_with_hocr, image_asset_with_null_hocr, sound_asset, child_work, image_asset_with_ocr_suppressed]
    )
  end

  describe "Work with OCR requested" do
    it "Summarizes assets with OCR correctly; displays show OCR button" do
      visit admin_work_path(work)

      click_on "OCR"
      expect(page).to have_text(/text extraction mode\:\s+OCR/i)
      expect(page).to have_text("Out of 5 assets")
      expect(page).to have_text("1 asset currently has extracted hocr text")
      expect(page).to have_text("1 asset has OCR suppressed")
      expect(page).to have_text("OCR enabled, but work does not include languages compatible with OCR.")

      click_on "Members"
      path_to_ocr = admin_asset_path(image_asset_with_hocr, anchor: "hocr")
      expect(page.find_all('table.member-list a.ocr-link').count).to eq 1
      expect(page).to have_link(:href=>path_to_ocr)
    end
  end
end
