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
    expect(FixityCheck.all[1].hash_function).to eq 'SHA512'

    expect { FixityChecker.new(nil).check }.
      to raise_error(ArgumentError)
    expect { FixityChecker.new(Work.new()).check }.
      to raise_error(ArgumentError)
  end

  it "does the right thing after an asset changes files (and uri's)" do
    FixityChecker.new(good_asset).check
    # Suppose good_asset gets a new file -- just faking this by
    # copying over file_data from good_asset_2.
    good_asset.file_data = good_asset_2.file_data
    good_asset.save!
    good_asset.reload
    expect(good_asset.file.url).to eq good_asset_2.file.url

    FixityChecker.new(good_asset).check
    latest_fixity_check = good_asset.fixity_checks[1]
    expect(good_asset.fixity_checks[0].checked_uri).not_to be == good_asset.fixity_checks[1].checked_uri
    # OK, now good_asset has two checks associated with it...
    expect(good_asset.fixity_checks.count).to eq 2
    # ... one for the old URI
    expect(FixityCheck.checks_for(good_asset, latest_fixity_check.checked_uri).count).to eq 1
    # ... and one for the new one.
    expect(FixityCheck.checks_for(good_asset, good_asset.fixity_checks[0].checked_uri).count).to eq 1
  end

  describe "pruning" do
    let(:good_asset) { build(:asset_image_with_correct_sha512) }
    let!(:twenty_checks) do
      (0..19).to_a.map do |x|
        create(:fixity_check,
          asset: good_asset,
          checked_uri: good_asset.file.url,
          created_at: Time.now() - 100000 * x,
          passed: [
            true, false, true, true, true, true, false, true, true, true,
            true, true, true, true, false, true, true, true, false, true][x]
        )
      end
    end
    it "correctly prunes excess fixity checks" do
      # If you change the number, this test is going to fail anyway
      # so at least fail in a way that's easy to catch.
      n_to_keep = FixityChecker::NUMBER_OF_RECENT_PASSED_CHECKS_TO_KEEP
      expect(n_to_keep).to eq 5
      expect(good_asset.fixity_checks.count).to eq 20
      passed_before = good_asset.fixity_checks.where(passed: true).count
      failed_before = good_asset.fixity_checks.where(passed: false).count
      earliest_passed = good_asset.fixity_checks.where(passed: true).last

      # These are the last checks that passed before a file was corrupted.
      last_known_good_checks, first_known_good_checks = [], []
      good_asset.fixity_checks.each_with_index do | ch, i |
        check_after_this = good_asset.fixity_checks[i-1]
        last_known_good_checks << ch if ch.passed? == true && check_after_this&.failed? == true
      end
      # And these are the first checks that passed after a corrupted file was fixed.
      good_asset.fixity_checks.to_a.each_with_index do | ch, i |
        check_before_this = good_asset.fixity_checks[i+1]
        first_known_good_checks << ch if ch.passed? == true && check_before_this&.failed? == true
      end

      FixityChecker.new(good_asset).prune_checks

      # Running prune_checks results in the extra checks going away
      expect(good_asset.fixity_checks.count).to eq 13
      passed_after  = good_asset.fixity_checks.where(passed: true).count
      failed_after  = good_asset.fixity_checks.where(passed: false).count
      # Failed checks are  not thrown out
      expect(failed_after).to eq failed_before
      # The earliest check is not thrown out
      expect(good_asset.fixity_checks.where(passed: true).last).to eq earliest_passed

      last_known_good_checks.each do |ch |
        # Don't throw out any of these.
        expect(good_asset.fixity_checks).to include ch
      end

      first_known_good_checks.each do |ch |
        # Or these.
        expect(good_asset.fixity_checks).to include ch
      end
    end
  end

  describe "#checked_uri_in_s3_console" do
    before do
      FixityChecker.new(corrupt_asset).check
    end
    let(:fixity_check) { corrupt_asset.fixity_checks.order(:created_at).last }

    describe "for local path not url" do
      it "returns nil" do
        expect(fixity_check.checked_uri_in_s3_console).to be nil
      end
    end

    describe "for S3 storage" do
      # fake the checked-uri to look like an S3 uri, cheesy but hopefully good
      # enough for a reliable test.
      let(:s3_url) { "https://some-bucket.s3.amazonaws.com/asset/b2c64027-7124-4388-9a32-57dba88156ba/f9a99647faa471f5b34b77316c0fbda5.tif" }
      before do
        fixity_check.checked_uri = s3_url
      end

      it "returns what we think is a good direct link to AWS console" do
        expect(fixity_check.checked_uri_in_s3_console).to eq "https://s3.console.aws.amazon.com/s3/buckets/some-bucket?region=us-east-1&prefix=asset/b2c64027-7124-4388-9a32-57dba88156ba/&prefixSearch=f9a99647faa471f5b34b77316c0fbda5.tif"
      end
    end

    describe "for some other non-S3 host" do
      before do
        fixity_check.checked_uri = "http://example.com/foo/bar"
      end
      it "returns nil" do
        expect(fixity_check.checked_uri_in_s3_console).to be nil
      end
    end
  end
end


