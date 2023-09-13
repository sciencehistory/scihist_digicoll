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

  describe "corrupt file" do
    let(:asset) {
      create(:asset, file: File.open(Rails.root + "spec/test_support/images/corrupt_bad.tiff"))
      #create(:asset, file: File.open(Rails.root + "/Users/jrochkind/Downloads/CORRUPT-soda_fountain_beverages_ncta7o9_156_4oaxl62.tiff"))
    }

    it "flags multiple errors" do
      expect(asset.exiftool_result["ExifTool:Validate"]).to be_present
      expect(asset.exiftool_result["ExifTool:Warning"]).to be_present


      # Warnings from exiftool are confusingly in hash under keys `ExifTool:Warning`, `ExifTool:Copy1:Warning`,
      # `ExifTool:Copy2:Warning`, etc.
      all_warnings = asset.exiftool_result.slice(
        *asset.exiftool_result.keys.grep(/ExifTool(:Copy\d+):Warning/)
      ).values

      expect(all_warnings).to include(
        "Missing required TIFF IFD0 tag 0x0100 ImageWidth",
        "Missing required TIFF IFD0 tag 0x0101 ImageHeight",
        "Missing required TIFF IFD0 tag 0x0106 PhotometricInterpretation",
        "Missing required TIFF IFD0 tag 0x0111 StripOffsets",
        "Missing required TIFF IFD0 tag 0x0116 RowsPerStrip",
        "Missing required TIFF IFD0 tag 0x0117 StripByteCounts",
        "Missing required TIFF IFD0 tag 0x011a XResolution",
        "Missing required TIFF IFD0 tag 0x011b YResolution"
      )
    end
  end
end
