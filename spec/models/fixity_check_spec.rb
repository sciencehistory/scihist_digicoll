require 'rails_helper'

describe FixityCheck do

  let(:good_asset)    { build(:asset_image_with_correct_sha512) }

  let(:good_asset_2)  { build(:asset_mp3_with_correct_sha512) }
  # :asset_with_faked_file, by factory default,comes with a random fake sha512.
  let(:corrupt_asset) { build(:asset_with_faked_file) }

  describe "missing S3 file" do
    let(:corrupt_asset) { build(:asset, friendlier_id: "faked", file_data: { storage: "store", id: "nosuchthing", metadata: { sha512: "whatever"}}) }

    it "records as failed" do
      FixityChecker.new(corrupt_asset).check

      check = corrupt_asset.fixity_checks.first
      expect(check).to be_present
      expect(check.passed?).to be(false)
      expect(check.actual_result).to eq "[file missing]"
    end
  end

  it "can check an asset's fixity sha512" do
    FixityChecker.new(good_asset).check
    FixityChecker.new(corrupt_asset).check
    expect(FixityCheck.count).to eq 2
    expect(FixityCheck.all[0].passed?).to be true
    expect(FixityCheck.all[1].failed?).to be true
    expect(FixityCheck.all[1].hash_function).to eq 'SHA-512'

    expect { FixityChecker.new(nil).check }.
      to raise_error(ArgumentError)
    expect { FixityChecker.new(Work.new()).check }.
      to raise_error(ArgumentError)

    # To check FixityCheck.checks_for method, let's
    # suppose good_asset gets a new file, and we check it again, and it passes.
    good_asset.file_data = good_asset_2.file_data
    good_asset.save!
    expect(good_asset.file.url).to eq good_asset_2.file.url
    FixityChecker.new(good_asset).check
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

    # Check pruning functionality:
    twenty_checks = (1..20).to_a.map { |x| FixityCheck.new(asset: good_asset) }
    twenty_checks.each_with_index do | c, i |
      c.passed = [
        true, false, true, true, true, true, false, true, true, true,
        true, true, true, true, false, true, true, true, false, true][i]
      c.checked_uri = good_asset.file.url
      c.created_at =  Time.now() - 100000 * i
      c.save!
    end

    # If you change the number, this test is going to fail anyway
    # so at least fail in a way that's easy to catch.
    n_to_keep = FixityChecker::NUMBER_OF_RECENT_PASSED_CHECKS_TO_KEEP
    expect(n_to_keep).to eq 5
    expect(good_asset.fixity_checks.count).to eq 22
    passed_before = good_asset.fixity_checks.where(passed: true).count
    failed_before = good_asset.fixity_checks.where(passed: false).count
    earliest_passed = good_asset.fixity_checks.where(passed: true).last
    FixityChecker.new(good_asset).prune_checks
    # We throw away a bunch of checks
    expect(good_asset.fixity_checks.count).to eq 11
    passed_after  = good_asset.fixity_checks.where(passed: true).count
    failed_after  = good_asset.fixity_checks.where(passed: false).count
    #We keep any checks that fail
    expect(failed_after).to eq failed_before
    #We keep the earliest passed check
    expect(good_asset.fixity_checks.where(passed: true).last).to eq earliest_passed
    #We keep at most n_to_keep recent passed checks, plus the oldest one.
    count_of_good_checks_kept = good_asset.fixity_checks.
      where(passed: true, checked_uri: good_asset.file.url).count
    expect(count_of_good_checks_kept).to eq n_to_keep + 1
  end
end
