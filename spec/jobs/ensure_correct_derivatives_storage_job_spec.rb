require 'rails_helper'

describe "EnsureCorrectDerivativesStorageJob" do
  let(:job) { EnsureCorrectDerivativesStorageJob.new(asset) }

  describe "with derivatives in incorrect public location" do
    let(:sample_file_location) {  Rails.root + "spec/test_support/images/20x20.png" }
    let(:asset) do
      # create one with no derivatives
      a = create(:asset_with_faked_file, :fake_dzi,
        derivative_storage_type: "restricted",
        faked_derivatives: {})

      derivatives_on_public_storage = {
        "thumb_small" => a.file_attacher.upload_derivative("thumb_small", File.open(sample_file_location), storage: :kithe_derivatives, delete: false),
        "thumb_large" => a.file_attacher.upload_derivative("thumb_large", File.open(sample_file_location), storage: :kithe_derivatives, delete: false),
      }

      a.file_attacher.set_derivatives(derivatives_on_public_storage)
      a.save!

      expect(a.file_derivatives.values.collect(&:storage_key)).to all(eq(:kithe_derivatives))

      a
    end

    it "moves derivatives to correct location" do
      original_derivatives = asset.file_derivatives.values

      job.perform_now

      expect(asset.file_derivatives.values).to be_present

      asset.file_derivatives.values.each do |deriv|
        expect(deriv.storage_key).to eq(:restricted_kithe_derivatives)
        expect(deriv.exists?).to be(true)
      end

      original_derivatives.each do |deriv|
        expect(deriv.exists?).to be(false)
      end
    end

    it "Deletes DZI files when ensuring restricted" do
      expect(Shrine.storages[:dzi_storage]).to receive(:delete_prefixed).with(
        asset.dzi_manifest_file.id.sub(/\.dzi$/, "_files/")
      )
      job.perform_now
    end
  end
end
