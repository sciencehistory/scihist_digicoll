# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkDownloadLinksComponent, type: :component do
  let!(:rendered) { render_inline(WorkDownloadLinksComponent.new(work)) }

  describe "multi-item work with OCR" do
    let(:work) do
      create(:work, :published, ocr_requested: true, members: [
        create(:asset_with_faked_file, :with_ocr),
        create(:asset_with_faked_file, :with_ocr)
      ])
    end


    it "has Searchable PDF link" do
      expect(page).to have_link("Searchable PDF")
    end

    it "has Zip link" do
      expect(page).to have_link("ZIP")
    end
  end

  describe "multi-item work without OCR" do
    let(:work) do
      create(:work, :published, members: [
        create(:asset_with_faked_file),
        create(:asset_with_faked_file)
      ])
    end

    it "has PDF link without Searchable" do
      expect(page).to have_link("PDF")
      expect(page).not_to have_link("Searchable PDF")
    end

    it "has Zip link" do
      expect(page).to have_link("ZIP")
    end
  end

  describe "single item work without OCR" do
    let(:work) do
      create(:work, :published, members: [
        create(:asset_with_faked_file)
      ])
    end

    it "does not have zip link" do
      expect(page).not_to have_link("ZIP")
    end
  end
end
