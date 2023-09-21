# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkDownloadLinksComponent, type: :component do
  let!(:rendered) { render_inline(WorkDownloadLinksComponent.new(work)) }

  describe "multi-item work with OCR" do
    let(:work) do
      create(:work, ocr_requested: true, members: [
        create(:asset, :with_ocr),
        create(:asset, :with_ocr)
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
      create(:work, members: [
        create(:asset),
        create(:asset)
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
end
