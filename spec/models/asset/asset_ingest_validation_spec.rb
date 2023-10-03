require 'rails_helper'

describe "Asset ingest validation" do
  describe "corrupt TIFF" do
    let(:corrupt_tiff_path) { Rails.root + "spec/test_support/images/corrupt_bad.tiff" }

    describe "inline promotion" do
      it "does not ingest" do
        asset = create(:asset, :inline_promoted_file, file: File.open(corrupt_tiff_path))

        expect(asset.ingest_validation_failed?).to be true

        expect(asset.file_attacher.cached?).to be true
        expect(asset.stored?).to be false

        # and has validation errors
        expect(asset.reload.ingest_validation_errors).to include(
          "Missing required TIFF IFD0 tag 0x0111 StripOffsets",
          "Missing required TIFF IFD0 tag 0x0116 RowsPerStrip",
          "Missing required TIFF IFD0 tag 0x0117 StripByteCounts",
          "Missing required TIFF IFD0 tag 0x0106 PhotometricInterpretation",
          "Missing required TIFF IFD0 tag 0x0100 ImageWidth",
          "Missing required TIFF IFD0 tag 0x0101 ImageHeight"
        )
      end
    end

    describe "async promotion", queue_adapter: :async do
      include ActiveJob::TestHelper

      it "does not ingest" do
        asset = nil
        perform_enqueued_jobs do
          asset = create(:asset, file: File.open(corrupt_tiff_path))
        end

        asset.reload

        expect(asset.ingest_validation_failed?).to be true
        expect(asset.reload.ingest_validation_errors).to be_present

        expect(asset.file_attacher.cached?).to be true
        expect(asset.stored?).to be false
      end
    end
  end
end
