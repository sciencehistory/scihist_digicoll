require 'rails_helper'

describe WorkShowOcrComponent do
  let(:component) { WorkShowOcrComponent.new(work) }

  describe "work with good OCR" do
    let(:work) do
      create(:work, ocr_requested: true, language: ["English"], members: [
        create(:asset, :with_ocr),
        create(:asset, :with_ocr),
        create(:asset, :suppress_ocr)
      ])
    end

    it "counts only #assets_with_ocr" do
      expect(component.assets_with_ocr).to eq 2
    end

    it "counts #assets_with_ocr_suppressed" do
      expect(component.assets_with_ocr_suppressed).to eq 1
    end

    it "counts total assets" do
      expect(component.total_assets).to eq work.members.size
    end

    it "does not have asset_ocr_count_warning?" do
      expect(component.asset_ocr_count_warning?).to be false
    end
  end

  describe "work with missing OCR" do
    let(:work) do
      create(:work, ocr_requested: true, language: ["English"], members: [
        create(:asset, :with_ocr),
        create(:asset)
      ])
    end

    it "counts only #assets_with_ocr" do
      expect(component.assets_with_ocr).to eq 1
    end

    it "counts total assets" do
      expect(component.total_assets).to eq work.members.size
    end

    it "has asset_ocr_count_warning?" do
      expect(component.asset_ocr_count_warning?).to be true
    end
  end
end
