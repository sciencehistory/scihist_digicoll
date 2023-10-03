require 'rails_helper'

describe "Asset ingest validation" do
  describe "corrupt TIFF" do
    let(:corrupt_tiff_path) { Rails.root + "spec/test_support/images/corrupt_bad.tiff" }

    it "does not ingest" do
      asset = create(:asset, :inline_promoted_file, file: File.open(corrupt_tiff_path))

      expect(asset.file_attacher.cached?).to be true
      expect(asset.stored?).to be false
    end
  end
end
