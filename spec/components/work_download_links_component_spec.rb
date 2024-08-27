# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkDownloadLinksComponent, type: :component do
  let!(:rendered) { render_inline(WorkDownloadLinksComponent.new(work)) }

  describe "multi-item work with OCR" do
    let(:work) do
      create(:work, :published, text_extraction_mode: 'ocr', members: [
        create(:asset_with_faked_file, :with_ocr),
        create(:asset_with_faked_file, :with_ocr)
      ])
    end


    it "has Searchable PDF link" do
      expect(page).to have_link("Searchable PDF") do |link|
        link["data-trigger"] == "on-demand-download" &&
        link["data-derivative-type"] == "pdf_file" &&
        link["data-work-id"] == work.friendlier_id &&
        link["data-analytics-category"] == "Work" &&
        link["data-analytics-action"] == "download_pdf" &&
        link["data-analytics-label"] == work.friendlier_id
      end
    end

    it "has Zip link" do
      expect(page).to have_link("ZIP") do |link|
        link["data-trigger"] == "on-demand-download" &&
        link["data-derivative-type"] == "zip_file" &&
        link["data-work-id"] == work.friendlier_id &&
        link["data-analytics-category"] == "Work" &&
        link["data-analytics-action"] == "download_zip" &&
        link["data-analytics-label"] == work.friendlier_id
      end
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

    it "does have a PDF link" do
      expect(page).to have_link("PDF")
    end
  end

  describe "zero item work with OCR requested" do
    let(:work) { create(:work, :published, members: [], text_extraction_mode: "ocr") }

    it "still has no PDF or zip link" do
      expect(page).not_to have_link("ZIP")
      expect(page).not_to have_link("PDF")
    end
  end
end
