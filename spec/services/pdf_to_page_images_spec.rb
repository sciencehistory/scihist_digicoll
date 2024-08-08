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
end
