require 'rails_helper'

describe "work with corrupt file attached" do
  let(:corrupt_tiff_path) { Rails.root + "spec/test_support/images/corrupt_bad.tiff" }
  let(:bad_asset) {create(:asset, :inline_promoted_file, file: File.open(corrupt_tiff_path))}
  let(:good_asset) {create(:asset, :inline_promoted_file) }
  let(:parent_work) { create(:work, :with_complete_metadata, published: false, members: [bad_asset, good_asset]) }
  before do
    allow(Rails.logger).to receive(:warn)
  end

  describe "attempt to publish" do
    it "refuses to publish" do
      expect(bad_asset.promotion_failed?).to be true
      # Work should be valid as long as it's not published
      expect(parent_work.reload.valid?).to be true

      expect { parent_work.update!(published: true) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(Rails.logger).to have_received(:warn).with(/.*couldn't be published. Something was wrong with asset*/)
    end
  end
end
