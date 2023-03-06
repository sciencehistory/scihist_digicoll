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
        expect(cli).to match( /\Atesseract [\/\.\-\w]+ - -l deu\+eng hocr\z/ )

        mocked_response
      end

      creator.call

      asset.reload
      expect(asset.hocr).to eq mocked_response.stdout
    end

  end
end
