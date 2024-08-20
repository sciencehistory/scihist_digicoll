require 'rails_helper'

describe "Asset ingest validation" do
  describe "corrupt TIFF" do
    let(:corrupt_tiff_path) { Rails.root + "spec/test_support/images/corrupt_bad.tiff" }

    before do
      allow(Rails.logger).to receive(:error)
    end

    describe "inline promotion" do
      it "does not ingest" do
        asset = create(:asset, :inline_promoted_file, file: File.open(corrupt_tiff_path))

        expect(asset.promotion_failed?).to be true

        expect(asset.file_attacher.cached?).to be true
        expect(asset.stored?).to be false

        # and has validation errors
        expect(asset.reload.promotion_validation_errors).to include(
          "Missing required TIFF IFD0 tag 0x0111 StripOffsets",
          "Missing required TIFF IFD0 tag 0x0116 RowsPerStrip",
          "Missing required TIFF IFD0 tag 0x0117 StripByteCounts",
          "Missing required TIFF IFD0 tag 0x0106 PhotometricInterpretation",
          "Missing required TIFF IFD0 tag 0x0100 ImageWidth",
          "Missing required TIFF IFD0 tag 0x0101 ImageHeight"
        )

        expect(Rails.logger).to have_received(:error).with(/\AAssetPromotionValidation\: Asset `#{asset.friendlier_id}` failed ingest/)
      end
    end

    describe "async promotion", queue_adapter: :async do
      it "does not ingest" do
        asset = create(:asset, file: File.open(corrupt_tiff_path))

        # Super hacky undocumented way to wait for Rails async bg job execution to complete
        # We want to test async in separate thread promotion cause it has separate concerns,
        # if this stops working, will have to figure out a better way to do so, or give up.
        # https://stackoverflow.com/questions/38315548/rails-async-active-job-doesnt-execute-code-while-inline-does
        executor = ActiveJob::Base._queue_adapter.instance_eval do
          @scheduler.instance_eval { @async_executor }
        end
        # wait until there are no scheduled jobs that haven't completed
        sleep(0.075) while executor.scheduled_task_count > executor.completed_task_count

        asset.reload

        expect(asset.promotion_failed?).to be true
        expect(asset.reload.promotion_validation_errors).to be_present

        expect(asset.file_attacher.cached?).to be true
        expect(asset.stored?).to be false

        expect(Rails.logger).to have_received(:error).with(/\AAssetPromotionValidation\: Asset `#{asset.friendlier_id}` failed ingest/)
      end
    end
  end

  describe ".promotion_failed scope" do
    let(:corrupt_tiff_path) { Rails.root + "spec/test_support/images/corrupt_bad.tiff" }
    let!(:good_asset) { create(:asset_with_faked_file)}
    let!(:bad_asset) { create(:asset, :inline_promoted_file, file: File.open(corrupt_tiff_path))}

    it "includes only failed assets" do
      failed = Asset.promotion_failed.to_a

      expect(failed.size).to be 1
      expect(failed.map(&:friendlier_id)).to include(bad_asset.friendlier_id)
      expect(failed.map(&:friendlier_id)).not_to include(good_asset.friendlier_id)
    end
  end

  describe "Unknown file type" do
    it "does not ingest" do
      asset = create(:asset, :inline_promoted_file, file: StringIO.new("not a recognized file type with binary data \xF0\xA4\xAD"))

      expect(asset.promotion_failed?).to be true
      expect(asset.file_attacher.cached?).to be true
      expect(asset.stored?).to be false

      expect(asset.reload.promotion_validation_errors).to include "Unknown/undetected content-type"
    end
  end
end
