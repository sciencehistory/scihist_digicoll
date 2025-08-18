require 'rails_helper'

describe AssetOcrCreator, type: :model do
  describe "with real tesseract" do
    let(:tiff_filepath) { "spec/test_support/images/text_and_embedded_thumb.tiff" }
    let(:asset) {
      create(:asset_with_faked_file,
        faked_file: tiff_filepath,
        faked_content_type: "image/tiff",
        faked_size: File.size(tiff_filepath),
        faked_metadata: { "dpi" => 150 },
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

    describe "with asset resizing" do
      before do
        # mock our limit super crazy small so we can demo the resize
        stub_const("AssetOcrCreator::MAX_INPUT_FILE_SIZE", asset.size - 10)

        # so we can check it later
        allow(Rails.logger).to receive(:warn)
        allow(creator).to receive(:downsample).and_call_original
      end

      it "resizes" do
        creator.call

        expect(creator).to have_received(:downsample)

        expect(Rails.logger).to have_received(:warn).
          with(/AssetOcrCreator: Downsampling asset #{asset.friendlier_id} for tesseract: .* @ 150 dpi, 30 px wide => .* @ 15 px wide/)

        expect(asset.hocr).to be_present

        expect(asset.admin_note).to include /OCR done on original downsampled by #{described_class::DEFAULT_DOWNSAMPLE_RATIO}/
      end
    end

    describe "asset with role extracted_pdf_page" do
      let(:asset) { create(:asset_with_faked_file, role: "extracted_pdf_page") }
      it "raises error" do
        expect {
          creator.call
        }.to raise_error(TypeError).with_message(/We refuse to OCR on a PDF with role extracted_pdf_page/)
      end
    end
  end
end
