require 'rails_helper'

describe "Asset exiftool characterization on ingest" do
  # do promotion inline to test what happens in promotion, and don't do derivatives at all -- we
  # don't need them and don't want to wait for them.
  around do |example|
    original = Kithe::Asset.promotion_directives
    Kithe::Asset.promotion_directives = { promote: :inline, create_derivatives: false }

    example.run

    Kithe::Asset.promotion_directives = original
  end

  describe "tiff" do
    let(:asset) {
      create(:asset, file: File.open(Rails.root + "spec/test_support/images/mini_page_scan.tiff"))
    }

    it "extracts exiftool result as hash with location prefix" do
      expect(asset.exiftool_result).to be_present
      expect(asset.exiftool_result).to be_kind_of(Hash)

      expect(asset.exiftool_result["ExifTool:ExifToolVersion"]).to match /^\d+(\.\d+)+$/

      # we add cli args...
      expect(asset.exiftool_result["Kithe:CliArgs"]).to be_present
      expect(asset.exiftool_result["Kithe:CliArgs"]).to be_kind_of Array


      expect(asset.exiftool_result["EXIF:BitsPerSample"]).to eq "8 8 8"
      expect(asset.exiftool_result["EXIF:PhotometricInterpretation"]).to eq "RGB"
      expect(asset.exiftool_result["EXIF:Compression"]).to eq "Uncompressed"
      expect(asset.exiftool_result["EXIF:Make"]).to eq "Phase One"
      expect(asset.exiftool_result["EXIF:Model"]).to eq "IQ3 80MP"

      expect(asset.exiftool_result["EXIF:XResolution"]).to eq 600
      expect(asset.exiftool_result["EXIF:YResolution"]).to eq 600

      expect(asset.exiftool_result["XMP:CreatorTool"]).to eq "Capture One 12 Macintosh"
      expect(asset.exiftool_result["XMP:Lens"]).to eq "-- mm f/--"
      expect(asset.exiftool_result["Composite:ShutterSpeed"]).to eq "1/60"
      expect(asset.exiftool_result["EXIF:ISO"]).to eq 50
      expect(asset.exiftool_result["ICC_Profile:ProfileDescription"]).to eq "Adobe RGB (1998)"
    end
  end

  describe "file that causes exiftool error" do
    let(:asset)  {
      create(:asset, file: File.open(Rails.root + "spec/test_support/audio/zero_bytes.flac"))
    }

    it "does not raise, and has error info stored" do
      expect(asset.exiftool_result).to be_present
      expect(asset.exiftool_result).to be_kind_of(Hash)

      expect(asset.exiftool_result["ExifTool:Error"]).to eq "File is empty"
    end
  end
end
