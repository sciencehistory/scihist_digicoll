require 'rails_helper'

describe AssetOcrCreator, type: :model do
  describe "with real tesseract" do
    let(:asset) {
      create(:asset_with_faked_file,
        faked_file: "spec/test_support/images/text_and_embedded_thumb.tiff",
        faked_content_type: "image/tiff",
        parent: create(:work, language: ["English"])
      )
    }
    let(:creator) { AssetOcrCreator.new(asset) }

    it "saves correct HOCR" do
      creator.call

      hocr = Nokogiri::HTML(asset.hocr) { |config| config.strict }

      # Make sure we only have one page, the embedded thumb was ignored
      hocr_pages = hocr.css(".ocr_page")
      expect(hocr_pages.length).to eq 1

      # not totally sure why tesseract is using "ocrx_word" instead of "ocr_word"
      expect(hocr.css(".ocrx_word").collect(&:text)).to eq(
        ["This", "is", "a", "sample", "TIFF", "with", "a", "line", "of", "text."]
      )
    end

    it "saves a text_only pdf" do
      creator.call

      asset.reload

      textonly_pdf_obj = asset.file_derivatives[:textonly_pdf]
      expect(textonly_pdf_obj).to be_present
      expect(textonly_pdf_obj.exists?).to be true

      textonly_pdf_file = textonly_pdf_obj.download

      # Make sure it looks like a PDF
      pdf_reader = PDF::Reader.new(textonly_pdf_file)
      expect(pdf_reader.pages.count).to eq 1
    end
  end
end
