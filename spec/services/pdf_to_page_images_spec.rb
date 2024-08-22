require 'rails_helper'
require 'marcel'

describe PdfToPageImages do
  let(:pdf_path) { Rails.root + "spec/test_support/pdf/sample-text-and-image-small.pdf"}
  let(:service) { PdfToPageImages.new(pdf_path) }

  describe "#extract_jpeg_for_page" do
    it "extracts a good image" do
      image_file = service.extract_jpeg_for_page(1)

      expect(image_file).to be_kind_of(Tempfile)
      expect(Marcel::MimeType.for(image_file)).to eq "image/jpeg"

      expect(Kithe::ExiftoolCharacterization.new.call(image_file.path)["EXIF:XResolution"]).to eq PdfToPageImages::DEFAULT_TARGET_DPI
    ensure
      image_file&.unlink
    end

    it "raises for 0" do
      expect {
        service.extract_jpeg_for_page(0)
      }.to raise_error(ArgumentError)
    end

    it "raises for too great out of bounds" do
      expect {
        service.extract_jpeg_for_page(10)
      }.to raise_error(ArgumentError)
    end
  end

  describe "#extract_hocr_for_page" do
    it "extracts hocr" do
      hocr = service.extract_hocr_for_page(1)

      expect(hocr).to be_kind_of String

      xml = Nokogiri::XML(hocr)  { |config| config.strict }

      expect(xml.css("div.ocr_page").length).to be 1
      expect(xml.css("div.ocr_carea")).to be_present
      expect(xml.css("div.ocr_line")).to be_present
      expect(xml.css("div.ocrx_word")).to be_present
    end

    it "raises for 0" do
      expect {
        service.extract_hocr_for_page(0)
      }.to raise_error(ArgumentError)
    end

    it "raises for too great out of bounds" do
      expect {
        service.extract_hocr_for_page(10)
      }.to raise_error(ArgumentError)
    end

    describe "on page with no text" do
      let(:pdf_path) { Rails.root + "spec/test_support/pdf/mini_page_scan_graphic_only.pdf"}

      it "returns nil" do
        expect(service.extract_hocr_for_page(1)).to be nil
      end
    end
  end

  describe "#create_asset_for_page", queue_adapter: :test do
    let(:work) { create(:work) }
    it "builds asset" do
      asset = service.create_asset_for_page(1, work: work)

      # We did enqueue a fixity check job, oh well, but shouldn't have enqueued
      # anything else
      expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to eq(1)
      expect(ActiveJob::Base.queue_adapter.enqueued_jobs.first["job_class"]).to eq "SingleAssetCheckerJob"

      expect(asset.valid?).to eq true
      expect(asset.persisted?).to eq true
      expect(asset.changed?).to eq false
      expect(asset.position).to eq 1
      expect(asset.extracted_pdf_source_info.page_index).to eq 1
      expect(asset.parent).to be work
      expect(asset.role).to eq PdfToPageImages::EXTRACTED_PAGE_ROLE

      expect(asset.stored?).to eq true
      expect(asset.content_type).to eq "image/jpeg"
      expect(asset.file_derivatives).to be_present
      expect(asset.file_metadata["dpi"]).to eq PdfToPageImages::DEFAULT_TARGET_DPI
      expect(asset.file_metadata["size"]).to be_present
      expect(asset.file_metadata["width"]).to be_present
      expect(asset.file_metadata["height"]).to be_present

      expect(asset.dzi_file).to be_present
      expect(asset.dzi_file.exists?).to be true

      expect(asset.hocr).to be_present
      xml = Nokogiri::XML(asset.hocr)  { |config| config.strict }
      expect(xml.css("div.ocr_page").length).to be 1

      asset.file.download do |image_file|
        expect(image_file).to be_kind_of(Tempfile)
        expect(Marcel::MimeType.for(image_file)).to eq "image/jpeg"
      end
    end
  end

  describe "#create_assets_for_pages" do
    let(:pdf_path) { Rails.root + "spec/test_support/pdf/3-page-text-and-image.pdf"}
    let(:work) { create(:work) }

    it "creates all assets" do
      service.create_assets_for_pages(work: work)

      extracted_assets = work.members.where(role: PdfToPageImages::EXTRACTED_PAGE_ROLE).order(:position).to_a

      expect(extracted_assets.count).to eq 3
      expect(extracted_assets.collect(&:position)).to eq [1,2,3]
      expect(extracted_assets.all? { |a| a.hocr.present? }).to be true
      expect(extracted_assets.all? { |a| a.file.present? }).to be true
    end
  end
end
