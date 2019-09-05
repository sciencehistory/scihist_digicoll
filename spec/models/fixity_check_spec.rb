require 'rails_helper'

describe FixityCheck do

  let(:good_asset)    { build(:asset_with_faked_file, :correct_sha512) }

  let(:good_asset_2)  { build(:asset_with_faked_file, :mp3_with_correct_sha512) }
  # :asset_with_faked_file, by factory default,comes with a random fake sha512.
  let(:corrupt_asset) { build(:asset_with_faked_file) }

  it "can check an asset's fixity sha512" do
    FixityCheck.check(good_asset)
    FixityCheck.check(corrupt_asset)
    expect(FixityCheck.count).to eq 2
    expect(FixityCheck.all[0].passed?).to be true
    expect(FixityCheck.all[1].failed?).to be true

    expect { FixityCheck.check(nil) }.
      to raise_error(ArgumentError)
    expect { FixityCheck.check(Work.new()) }.
      to raise_error(ArgumentError)

    # To check FixityCheck.checks_for method, let's
    # suppose good_asset gets a new file, and we check it again, and it passes.
    good_asset.file_data = good_asset_2.file_data
    good_asset.save!
    expect(good_asset.file.url).to eq good_asset_2.file.url
    FixityCheck.check(good_asset)
    expect(good_asset.fixity_checks[0].checked_uri).not_to be == good_asset.fixity_checks[1].checked_uri


    # TODO would be nice if we could do this without modifying the fixity check directly.
    latest_fixity_check = good_asset.fixity_checks[1]
    latest_fixity_check.actual_result = latest_fixity_check.expected_result
    latest_fixity_check.passed = true
    latest_fixity_check.save!
    # end TODO

    expect(good_asset.fixity_checks.count).to eq 2
    expect(FixityCheck.checks_for(good_asset, latest_fixity_check.checked_uri).count).to eq 1
    expect(FixityCheck.checks_for(good_asset, good_asset.fixity_checks[0].checked_uri).count).to eq 1
  end
end
