require 'rails_helper'

describe "Asset ingest validation" do
  describe "corrupt TIFF" do
    let(:corrupt_tiff_path) { Rails.root + "spec/test_support/images/corrupt_bad.tiff" }

    it "does not ingest" do
      asset = create(:asset, :inline_promoted_file, file: File.open(corrupt_tiff_path))

      expect(asset.file_attacher.cached?).to be true
      expect(asset.stored?).to be false

      # and has validation errors
      expect(asset.reload.file_metadata["ingest_validation_errors"]).to include(
        "Missing required TIFF IFD0 tag 0x0111 StripOffsets",
        "Missing required TIFF IFD0 tag 0x0116 RowsPerStrip",
        "Missing required TIFF IFD0 tag 0x0117 StripByteCounts",
        "Missing required TIFF IFD0 tag 0x0106 PhotometricInterpretation",
        "Missing required TIFF IFD0 tag 0x0100 ImageWidth",
        "Missing required TIFF IFD0 tag 0x0101 ImageHeight"
      )
    end
  end
end
