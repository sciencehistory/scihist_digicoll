require 'rails_helper'

describe FixityCheckLog do

  let(:good_asset)    { build(:asset_with_faked_file, :correct_sha512) }
  # :asset_with_faked_file by factory default comes with a random fake sha512.
  let(:corrupt_asset) { build(:asset_with_faked_file) }

  it "can check an asset's fixity sha512" do
    FixityCheckLog.check(good_asset)
    FixityCheckLog.check(corrupt_asset)
    expect(FixityCheckLog.count).to eq 2
    expect(FixityCheckLog.all[0].passed).to be true
    expect(FixityCheckLog.all[1].passed).to be false
  end
end
