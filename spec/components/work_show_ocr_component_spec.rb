require 'rails_helper'

describe WorkShowOcrComponent, type: :component do
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
      expect(component.assets_with_ocr_count).to eq 2
    end

    it "counts #assets_with_ocr_suppressed" do
      expect(component.assets_with_ocr_suppressed_count).to eq 1
    end

    it "counts total assets" do
      expect(component.total_assets_count).to eq work.members.size
    end

    it "does not have asset_ocr_count_warning?" do
      expect(component.asset_ocr_count_warning?).to be false
    end

    it "renders" do
      render_inline(component)
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
      expect(component.assets_with_ocr_count).to eq 1
    end

    it "counts total assets" do
      expect(component.total_assets_count).to eq work.members.size
    end

    it "has asset_ocr_count_warning?" do
      expect(component.asset_ocr_count_warning?).to be true
    end

    it "renders" do
      render_inline(component)
    end
  end

  describe "work with good PDF extraction" do
    let(:work) do
      create(:work, text_extraction_mode: "pdf_extraction", language: ["English"], members: [
        create(:asset_with_faked_file, :pdf, role: "work_source_pdf", faked_metadata: { page_count: 1}),
        create(:asset, :with_ocr, role: "extracted_pdf_page")
      ])
    end

    it "counts #assets_with_ocr" do
      expect(component.assets_with_ocr_count).to eq 1
    end

    it "counts total assets" do
      expect(component.total_assets_count).to eq 2
    end

    it "counts assets_with_extracted_pdf_page_role" do
      expect(component.assets_with_extracted_pdf_page_role_count).to eq 1
    end

    it "counts assets_with_source_pdf_role" do
      expect(component.assets_with_source_pdf_role_count).to eq 1
    end

    it "finds source PDF page count" do
      expect(component.source_pdf_page_count).to eq 1
    end

    it "does not have asset_ocr_count_warning?" do
      expect(component.asset_ocr_count_warning?).to be false
    end

    it "does not have pdf_extraction_count_warning?" do
      expect(component.pdf_extraction_count_warning?).to be false
    end

    it "renders" do
      render_inline(component)
    end
  end

  describe "work with bad PDF extraction" do
    let(:work) do
      create(:work, text_extraction_mode: "pdf_extraction", language: ["English"], members: [
        create(:asset_with_faked_file, :pdf, role: "work_source_pdf", faked_metadata: { page_count: 1} ),
      ])
    end

    it "counts #assets_with_ocr" do
      expect(component.assets_with_ocr_count).to eq 0
    end

    it "counts total assets" do
      expect(component.total_assets_count).to eq 1
    end

    it "counts assets_with_extracted_pdf_page_role" do
      expect(component.assets_with_extracted_pdf_page_role_count).to eq 0
    end

    it "counts assets_with_source_pdf_role" do
      expect(component.assets_with_source_pdf_role_count).to eq 1
    end

    it "does not have asset_ocr_count_warning?" do
      expect(component.asset_ocr_count_warning?).to be false
    end

    it "has pdf_extraction_count_warning?" do
      expect(component.pdf_extraction_count_warning?).to be true
    end

    it "renders" do
      render_inline(component)
    end
  end
end
