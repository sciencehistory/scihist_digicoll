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

    describe "on page with no text" do
      let(:pdf_path) { Rails.root + "spec/test_support/pdf/mini_page_scan_graphic_only.pdf"}

      it "returns nil" do
        expect(service.extract_hocr_for_page(1)).to be nil
      end
    end
  end
end
