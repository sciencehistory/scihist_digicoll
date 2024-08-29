require 'rails_helper'

describe WorkOcrCreatorRemover, queue_adapter: :test do
  let(:image_asset_without_hocr) { create(:asset_with_faked_file) }
  let(:image_asset_with_ocr_suppressed) { create(:asset_with_faked_file, :suppress_ocr, title: "Asset with OCR suppressed") }
  let(:image_asset_with_ocr_suppressed_but_with_derivs) do
    create(:asset_with_faked_file,
      :suppress_ocr, title: "Asset with OCR suppressed BUT with derivs", hocr:'remove this hocr', faked_derivatives: {
        textonly_pdf: create(:stored_uploaded_file, content_type: "application/pdf")
      }
    )
  end

  let(:image_asset_with_hocr) do
    create(:asset_with_faked_file,
      hocr: "goat",
      faked_derivatives: {
        textonly_pdf: create(:stored_uploaded_file, content_type: "application/pdf")
      }
    )
  end
  let(:image_asset_with_hocr) do
    create(:asset_with_faked_file,
      hocr: "goat",
      faked_derivatives: {
        textonly_pdf: create(:stored_uploaded_file, content_type: "application/pdf")
      }
    )
  end

  let(:sound_asset) { create(:asset_with_faked_file, :m4a) }
  let(:child_work)  { create(:public_work, representative: create(:asset_with_faked_file)) }

  let(:work) do
    create(:public_work,
      language: 'English',
      ocr_requested: ocr_requested,
      members: [
        image_asset_without_hocr,
        image_asset_with_ocr_suppressed,
        image_asset_with_ocr_suppressed_but_with_derivs,
        image_asset_with_hocr,
        sound_asset,
        child_work
      ]
    )
  end

  context "work needs OCR" do
    let(:ocr_requested) { true }

    it "enqueues an ocr creation job for assets that need it; removes OCR and textonly_pdf from works that don't" do
      WorkOcrCreatorRemover.new(work).process
      expect(CreateAssetOcrJob).to have_been_enqueued.with(image_asset_without_hocr)
      expect(CreateAssetOcrJob).not_to have_been_enqueued.with(image_asset_with_hocr)
      expect(CreateAssetOcrJob).not_to have_been_enqueued.with(sound_asset)
      expect(CreateAssetOcrJob).not_to have_been_enqueued.with(child_work)
      expect(CreateAssetOcrJob).not_to have_been_enqueued.with(image_asset_with_ocr_suppressed)
      expect(CreateAssetOcrJob).not_to have_been_enqueued.with(image_asset_with_ocr_suppressed_but_with_derivs)
      image_asset_with_ocr_suppressed_but_with_derivs.reload
      expect(image_asset_with_ocr_suppressed_but_with_derivs.file_derivatives.keys).to eq []
      expect(image_asset_with_ocr_suppressed_but_with_derivs.hocr).to be_nil
    end

    context "but does not have suitable language metadata" do
      let(:work) do
        create(:public_work,
          language: [],
          ocr_requested: true,
          members: [
            image_asset_without_hocr,
            image_asset_with_hocr,
            sound_asset,
            child_work
          ]
        )
      end

      it "does not enqueue CreateAssetOcrJob" do
        WorkOcrCreatorRemover.new(work).process
        expect(CreateAssetOcrJob).not_to have_been_enqueued
      end
    end

    context "with extracted_pdf_page" do
      let(:asset) { create(:asset_with_faked_file, hocr: "test hocr", role: PdfToPageImages::EXTRACTED_PAGE_ROLE, faked_derivatives: {}) }
      let(:work) do
        create(:public_work,
          language: 'English',
          ocr_requested: true,
          members: [ asset ]
        )
      end

      it "does not enqueue CreateAssetOcrJob" do
        WorkOcrCreatorRemover.new(work).process
        expect(CreateAssetOcrJob).not_to have_been_enqueued
      end
    end
  end

  context "work does not need OCR" do
    let(:ocr_requested) { false }
    it "removes OCR" do
      WorkOcrCreatorRemover.new(work).process
      work.reload
      work.members.each do |m|
        expect(CreateAssetOcrJob).not_to have_been_enqueued.with(m)
        expect(m.hocr).to be_nil if m.asset?
        expect(m.file_derivatives[:textonly_pdf]).to be_nil if m.asset?
      end
    end

    context "with extracted_pdf_page" do
      let(:asset) { create(:asset_with_faked_file, hocr: "test hocr", role: PdfToPageImages::EXTRACTED_PAGE_ROLE, faked_derivatives: {}) }
      let(:work) do
        create(:public_work,
          ocr_requested: false,
          members: [ asset ]
        )
      end

      it "leaves hocr alone" do
        WorkOcrCreatorRemover.new(work).process

        expect(asset.reload.hocr).to eq "test hocr"
      end
    end
  end
end
