require 'rails_helper'

describe AssetHocrCreator, type: :model do
  describe "with mocked tesseract" do
    let(:asset) { create(:asset_with_faked_file, parent: create(:work, language: ["German", "English", "Japanese"])) }
    let(:creator) { AssetHocrCreator.new(asset) }
    let(:creator_tty_command_obj) { creator.send(:tty_command) }
    let(:mocked_response) { TTY::Command::Result.new(0, "mocked HOCR output", "whatever tesseract prints to stderr") }

    before do
      allow(creator_tty_command_obj).to receive(:run).and_return(mocked_response)
    end


    it "calls proper tesseract command and persists output" do
      expect(creator_tty_command_obj).to receive(:run) do |*args|
        cli = args.join(" ")

        # just what we expect a cli call to be, including proper language tags,
        # in order, ignoring Japanese that we aren't prepared to OCR.
        expect(cli).to match( /\Atesseract -c tessedit_page_number=0 [\/\.\-\w]+ - -l deu\+eng hocr\z/ )

        mocked_response
      end

      creator.call

      asset.reload
      expect(asset.hocr).to eq mocked_response.stdout
    end
  end

  describe "with real tesseract" do
    let(:asset) {
      create(:asset_with_faked_file,
        faked_file: "spec/test_support/images/text_and_embedded_thumb.tiff",
        faked_content_type: "image/tiff",
        parent: create(:work, language: ["English"])
      )
    }
    let(:creator) { AssetHocrCreator.new(asset) }

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
  end
end
