require 'rails_helper'

describe "work with corrupt file attached" do
  let(:corrupt_tiff_path) { Rails.root + "spec/test_support/images/corrupt_bad.tiff" }
  let(:asset) {create(:asset, :inline_promoted_file, file: File.open(corrupt_tiff_path))}
  let(:parent_work) { create(:work, :with_complete_metadata, published: false, members: [asset]) }
  before do
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:warn)
  end

  describe "publish the work" do
    it "can't publish the work" do
      expect(asset.promotion_failed?).to be true
      # Work should be valid as long as it's not published
      expect(parent_work.reload.valid?).to be true
      expect { parent_work.update!(published: true) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(Rails.logger).to have_received(:warn).with(/.*couldn't be published. Something was wrong with asset*/)
    end
  end
end
