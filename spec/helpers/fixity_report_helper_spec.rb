require 'rails_helper'

describe FixityReportHelper do

  # A recent asset with a file with no checks
  let!(:a0) { create(:asset_image_with_correct_sha512, friendlier_id: '000') }

  # An older asset, ingested 2 weeks ago.
  let(:a1) { create(
    :asset_image_with_correct_sha512,
    friendlier_id: '111',
    created_at: Time.now() - 10000000,
  ) }
  # Three assets ingested today, two with files
  let(:a2) { create(:asset_image_with_correct_sha512, friendlier_id: '222') }
  let(:a3) { create(:asset_image_with_correct_sha512, friendlier_id: '333') }
  # ... and one without.
  let!(:a4) { create(:asset) }

  # Let's check the 3 assets with files a bunch of times.
  let!(:twenty_checks) do
    (0..19).to_a.map do |x|
      the_asset = [a1, a2, a3][ x % 3 ]
      create(:fixity_check,
        asset: the_asset,
        checked_uri: the_asset.file.url,
        created_at: Time.now() - 100000 * ( x + 1 ),
        passed: [
          true, false, true, true, true, true, false, true, true, true,
          true, true, true, true, false, true, true, true, false, true][x]
      )
    end
  end

  it "correctly counts the assets and fixity checks" do
    report_1 = FixityReportHelper::FixityReportHelper.new()
    # OK we have 3 assets, with the a bunch of fixity checks attached to them.

    # These are, in REVERSE CHRON ORDER:
    # Most recent checks are first.
    expect(a1.fixity_checks.map{ |fc| fc.passed?}).to eq [true,  true, false, true, true,  true, false]
    expect(a2.fixity_checks.map{ |fc| fc.passed?}).to eq [false, true, true,  true, true,  true, true]
    expect(a3.fixity_checks.map{ |fc| fc.passed?}).to eq [true,  true, true,  true, false, true]

    # The report counts our 5 assets.
    expect(report_1.asset_count).to eq 5

    # a1, a2 and a3 failed their checks at some point in the past.
    # But the only one that should be reported as currently
    # failing is a2, since its most recent check has failed.
    expect(report_1.bad_assets).to match_array([a2])

    # All assets except a4 have files
    expect(report_1.stored_files).to eq 4

    # a4 has no stored file.
    expect(report_1.no_stored_files).to eq 1

    # Assets a1, a2 and a3 have checks.
    expect(report_1.with_checks).to eq 3

    # a1, a2 and a3 have recent checks
    expect(report_1.recent_checks).to eq 3

    # All the items with checks have recent ones.
    expect(report_1.stale_checks).to eq 0

    # All assets except a1 are less than a week old.
    # Asset a4 doesn't have a file yet so we don't
    # care whether it's recent for fixity check purposes.
    # That leaves a0, a2 and a3.
    expect(report_1.recent_files).to eq 3

    # All assets with checks have recent checks, but a0 still needs to be checked.
    expect(report_1.no_checks_or_stale_checks).to eq 1

    # Asset a1 is not recent, but it's been checked this week.
    expect(report_1.not_recent_with_no_checks_or_stale_checks).to eq 0

    # New scenario:
    # Fixity checking has something wrong with it
    # and assets a1 and a2 have not been
    # checked for over a week. To simulate this, we just
    # get rid of their three most recent checks and rerun a report.
    a1.fixity_checks[0..2].each { |x| x.delete }
    a2.fixity_checks[0..2].each { |x| x.delete }
    a1.reload
    a2.reload

    report_2 = FixityReportHelper::FixityReportHelper.new()

    expect(a1.fixity_checks.map{ |fc| fc.passed?}).to eq [true, true, true, false]
    expect(a2.fixity_checks.map{ |fc| fc.passed?}).to eq [true, true, true, true]
    expect(a3.fixity_checks.map{ |fc| fc.passed?}).to eq [true,  true, true,  true, false, true]

    # In this scenario:
    # All assets with fixity checks have their most recent check passing.
    expect(report_2.bad_assets).to match_array([])

    # Still 4 assets.
    expect(report_2.asset_count).to eq 5

    # Four have stored files: a0, a1, a2 and a3.
    expect(report_2.stored_files).to eq 4

    #a0 has no file.
    expect(report_2.no_stored_files).to eq 1

    # a0 has no checks
    expect(report_2.no_checks).to eq 1

    # 3 have checks
    expect(report_2.with_checks).to eq 3

    # a3 is now the only one with recent checks:
    expect(report_2.recent_checks).to eq 1

    # a1 and a2 have stale checks now
    expect(report_2.stale_checks).to eq 2

    # a0, a2 and a3 are recent assets with files.
    expect(report_2.recent_files).to eq 3

    # a0 (no checks yet) a1 (checks stale) and a2 (checks also stale) need to get checked.
    expect(report_2.no_checks_or_stale_checks).to eq 3

    # a1 was ingested more than a week ago but it hasn't been checked for over a week.
    # Sound the alarm!
    expect(report_2.not_recent_with_no_checks_or_stale_checks).to eq 1
  end
end
