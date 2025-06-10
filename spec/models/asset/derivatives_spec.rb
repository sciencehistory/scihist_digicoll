require 'rails_helper'

describe "derivative creation" do

  let(:flac_file_path) { Rails.root.join("spec/test_support/audio/5-seconds-of-silence.flac")}
  let(:flac_file_sha512) { Digest::SHA512.hexdigest(File.read(flac_file_path)) }
  let!(:flac_asset) { FactoryBot.create(:asset, file: File.open(flac_file_path)) }

  let(:mp3_file_path) { Rails.root.join("spec/test_support/audio/5-seconds-of-silence.mp3")}
  let(:mp3_file_sha512) { Digest::SHA512.hexdigest(File.read(mp3_file_path)) }
  let!(:mp3_asset) { FactoryBot.create(:asset, file: File.open(mp3_file_path)) }


  describe 'pdf asset' do
    let!(:pdf_asset) { create(:asset_with_faked_file, :pdf, faked_derivatives: {}) }
    it "creates pdf derivatives" do
      pdf_asset.create_derivatives
      expect(pdf_asset.file_derivatives.keys.sort).
        to contain_exactly(:thumb_large,:thumb_large_2X,
          :thumb_mini, :thumb_mini_2X,
          :thumb_standard, :thumb_standard_2X
        )
      expect(pdf_asset.file_derivatives[:thumb_mini].metadata['width']).to eq(54)
      expect(pdf_asset.file_derivatives[:thumb_large_2X].metadata['width']).to eq(1050)
    end
  end

  describe "video asset" do
    let!(:video_asset) { create(:asset_with_faked_file, :video, faked_derivatives: {}) }

    it "extracts a frame for thumbnails and a compact opus audio" do
      video_asset.create_derivatives

      expect(video_asset.file_derivatives.keys).to include(
        :thumb_mini, :thumb_mini_2X, :thumb_large, :thumb_large_2X, :thumb_standard, :thumb_standard_2X, :audio_16k_opus
      )

      expect(video_asset.file_derivatives[:audio_16k_opus].content_type).to eq "audio/opus"
      expect(video_asset.file_derivatives[:audio_16k_opus].size).to be > 0

      # our stack is currently getting confused and producing '.bin', but everything works, so oh well for now.
      expect(video_asset.file_derivatives[:audio_16k_opus].metadata["filename"]).to end_with(".oga")
    end
  end

  describe "audio asset" do
    describe "flac" do
      it "creates audio derivatives" do
        flac_asset.file.metadata['sha512'] = flac_file_sha512
        flac_asset.save!
        flac_asset.create_derivatives
        expect(flac_asset.file_derivatives).to have_key :m4a
        m4a_deriv  = flac_asset.file_derivatives.dig(:m4a) #flac_asset.file_derivatives[:m4a]
        expect(m4a_deriv).not_to be_nil
        expect(m4a_deriv.mime_type).to eq('audio/mp4')
        # TODO can this be changed to m4a? Should we?
        expect(m4a_deriv.id).to match(/mp4$/)
      end
    end

    describe "mp3" do
      it "does not have an m4a derivative" do
        mp3_asset.create_derivatives
        expect(mp3_asset.file_derivatives).not_to have_key :m4a
      end
    end
  end

  describe "TIFF asset" do
    let(:tiff_file_path) { Rails.root.join("spec/test_support/images/mini_page_scan.tiff") }
    let!(:asset) { FactoryBot.create(:asset, file: File.open(tiff_file_path)) }

    it "can create a graphiconly_pdf derivative" do
      asset.create_derivatives(only: :graphiconly_pdf)
      expect(asset.file_derivatives).to have_key(:graphiconly_pdf)
    end
  end
end
