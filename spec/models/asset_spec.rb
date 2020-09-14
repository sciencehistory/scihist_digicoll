require 'rails_helper'

describe Asset do
  describe ".all_derivative_count" do
    let!(:assets) { [create(:asset_with_faked_file), create(:asset_with_faked_file)]}

    it "returns good count" do
      expected = assets.collect { |a| a.file_derivatives.count }.sum

      expect(expected).to be > 0
      expect(Asset.all_derivative_count).to eq(expected)
    end
  end

  describe "restricted derivatives", queue_adapter: :inline do
    let(:sample_file_location) {  Rails.root + "spec/test_support/images/20x20.png" }
    let(:asset) { create(:asset, derivative_storage_type: "restricted") }
    it "are stored in restricted derivatives location" do
      asset.file = File.open(sample_file_location)
      asset.save!
      asset.reload

      derivatives = asset.file_derivatives.values

      expect(derivatives).to all(satisfy { |d| d.storage_key == :restricted_kithe_derivatives })
      expect(asset.derivatives_in_correct_storage_location?).to be(true)
    end

    describe "with derivatives in wrong location" do
      let(:asset) do
        # create one with no derivatives
        a = create(:asset_with_faked_file,
          derivative_storage_type: "restricted",
          faked_derivatives: {})

        derivatives_on_public_storage = {
          "thumb_small" => a.file_attacher.upload_derivative("thumb_small", File.open(sample_file_location), storage: :kithe_derivatives, delete: false),
          "thumb_large" => a.file_attacher.upload_derivative("thumb_large", File.open(sample_file_location), storage: :kithe_derivatives, delete: false),
        }

        a.file_attacher.set_derivatives(derivatives_on_public_storage)
        a.save!

        a
      end

      it "#derivatives_in_correct_storage_location? is false" do
        expect(asset.derivatives_in_correct_storage_location?).to be(false)
      end
    end
  end
end
