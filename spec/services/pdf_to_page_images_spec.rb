require 'rails_helper'
require 'marcel'

describe PdfToPageImages do
  let(:pdf_path) { Rails.root + "spec/test_support/pdf/sample-text-and-image-small.pdf"}
  let(:service) { PdfToPageImages.new(pdf_path) }

  let(:stub_jpeg_path) { Rails.root + "spec/test_support/images/30x30.jpg" }
  let(:sample_hocr) { File.read(Rails.root + "spec/test_support/hocr_xml/extract_from_pdf_sample.300.hocr") }

  # Each call gets a fresh Tempfile copy so the service's ensure-block cleanup
  # doesn't break things across multiple calls.
  def stub_extract_jpeg_for_page(service)
    jpeg_path = stub_jpeg_path
    allow(service).to receive(:extract_jpeg_for_page) do
      t = Tempfile.new(["page_", ".jpg"])
      t.binmode
      t.write(File.binread(jpeg_path.to_s))
      t.rewind
      t
    end
  end

  def stub_extract_hocr_for_page(service)
    allow(service).to receive(:extract_hocr_for_page).and_return(sample_hocr)
  end

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
      asset = service.create_asset_for_page(1, work: work, source_pdf_sha512: "fakesha512", source_pdf_asset_pk: "fakeassetid")

      # We did enqueue a fixity check job, oh well, but shouldn't have enqueued
      # anything else
      expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to eq(1)
      expect(ActiveJob::Base.queue_adapter.enqueued_jobs.first["job_class"]).to eq "SingleAssetCheckerJob"

      expect(asset.valid?).to eq true
      expect(asset.persisted?).to eq true
      expect(asset.changed?).to eq false
      expect(asset.position).to eq 1
      expect(asset.extracted_pdf_source_info.page_index).to eq 1
      expect(asset.extracted_pdf_source_info.source_pdf_sha512).to eq "fakesha512"
      expect(asset.extracted_pdf_source_info.source_pdf_asset_pk).to eq "fakeassetid"
      expect(asset.title).to eq "0001 page extracted from #{work.friendlier_id}"

      expect(asset.parent).to be work
      expect(asset.role).to eq PdfToPageImages::EXTRACTED_PAGE_ROLE

      expect(asset.stored?).to eq true
      expect(asset.content_type).to eq "image/jpeg"
      expect(asset.file_derivatives).to be_present
      expect(asset.file_metadata["dpi"]).to eq PdfToPageImages::DEFAULT_TARGET_DPI
      expect(asset.file_metadata["size"]).to be_present
      expect(asset.file_metadata["width"]).to be_present
      expect(asset.file_metadata["height"]).to be_present

      expect(asset.dzi_package).to be_present
      expect(asset.dzi_package.exists?).to be true

      expect(asset.hocr).to be_present
      xml = Nokogiri::XML(asset.hocr)  { |config| config.strict }
      expect(xml.css("div.ocr_page").length).to be 1

      asset.file.download do |image_file|
        expect(image_file).to be_kind_of(Tempfile)
        expect(Marcel::MimeType.for(image_file)).to eq "image/jpeg"
      end
    end

    describe "on_existing_dup" do
      let!(:duplicate) { create(:asset_with_faked_file, :pdf, :fake_dzi, parent: work, extracted_pdf_source_info: { page_index: 1 }) }
      let!(:original_file_id) { duplicate.file.id }
      let!(:original_dzi_id) { duplicate.dzi_manifest_file.id }
      let!(:original_derivatives_json) { duplicate.file_derivatives.as_json }

      it ":abort uses existing without update" do
        asset = service.create_asset_for_page(1, work: work, on_existing_dup: :abort, source_pdf_sha512: nil, source_pdf_asset_pk: nil)

        expect(asset.id).to eq duplicate.id
        expect(Asset.jsonb_contains("extracted_pdf_source_info.page_index" => 1).where(parent_id: work.id).count).to eq 1

        expect(asset.hocr).to be nil
        expect(asset.file&.id).to eq original_file_id
      end

      it ":overwrite uses existing with update", queue_adapter: :test do
        stub_extract_jpeg_for_page(service)
        stub_extract_hocr_for_page(service)
        asset = service.create_asset_for_page(1, work: work, on_existing_dup: :overwrite, source_pdf_sha512: "newsha512", source_pdf_asset_pk: "newid")

        expect(asset.id).to eq duplicate.id
        expect(Asset.jsonb_contains("extracted_pdf_source_info.page_index" => 1).where(parent_id: work.id).count).to eq 1

        asset.reload

        expect(asset.hocr).not_to be nil
        expect(asset.file).not_to be nil

        expect(asset.extracted_pdf_source_info.source_pdf_sha512).to eq "newsha512"
        expect(asset.extracted_pdf_source_info.source_pdf_asset_pk).to eq "newid"

        # it should have new derivatives and dzi created, all inline!
        expect(asset.dzi_package&.present?).to eq true
        expect(asset.dzi_package.dzi_manifest_file.id).not_to eq original_dzi_id

        expect(asset.file_derivatives).to be_present
        expect(asset.file_derivatives.as_json).not_to eq original_derivatives_json

        # Everything should have been inline, no bg job but fixity, which we don't
        # really care about but it's fine. Also has some delete jobs

        enqueued_jobs = ActiveJob::Base.queue_adapter.enqueued_jobs.collect { |h| h["job_class"] }
        expect(enqueued_jobs.all? { |job_name| job_name.in?(["SingleAssetCheckerJob", "DeleteDziJob", "Kithe::AssetDeleteJob"]) })
      end

      it ":insert_dup just inserts anyway" do
        stub_extract_jpeg_for_page(service)
        stub_extract_hocr_for_page(service)
        asset = service.create_asset_for_page(1, work: work, on_existing_dup: :insert_dup, source_pdf_sha512: nil, source_pdf_asset_pk: nil)

        expect(asset.id).not_to eq duplicate.id
        expect(Asset.jsonb_contains("extracted_pdf_source_info.page_index" => 1).where(parent_id: work.id).count).to eq 2

        expect(asset.hocr).not_to be nil
        expect(asset.file).not_to be nil
        expect(asset.file.id).not_to eq original_file_id
      end
    end
  end

  # This one is super slow if we don't mock create_asset_for_page individually, test that
  # itself please.
  describe "#create_assets_for_pages, mocked" do
    let(:pdf_path) { Rails.root + "spec/test_support/pdf/3-page-text-and-image.pdf"}
    let(:work) { create(:work) }

    it "creates asset for each page" do
      allow(service).to receive(:create_asset_for_page)

      service.create_assets_for_pages(work: work, source_pdf_sha512: nil, source_pdf_asset_pk: nil)

      (1..service.num_pdf_pages).each do |page_num|
        expect(service).to have_received(:create_asset_for_page).ordered.
          with(
            page_num,
            work: work,
            on_existing_dup: :insert_dup,
            source_pdf_sha512: nil,
            source_pdf_asset_pk: nil
          )
      end
    end
  end
end
