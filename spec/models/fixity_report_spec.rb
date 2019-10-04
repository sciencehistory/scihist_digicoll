require 'rails_helper'

describe FixityReport do
  # A recent asset with a file with no checks
  let!(:recent_asset_no_checks) { create(:asset_image_with_correct_sha512, friendlier_id: '000') }

  # An older asset, ingested 2 weeks ago.
  let(:old_asset) { create(
    :asset_image_with_correct_sha512,
    friendlier_id: '111',
    created_at: Time.now() - 10000000,
  ) }
  # Three assets ingested today, two with files
  let(:recent_asset_with_file_1) { create(:asset_image_with_correct_sha512, friendlier_id: '222') }
  let(:recent_asset_with_file_2) { create(:asset_image_with_correct_sha512, friendlier_id: '333') }
  # ... and one without.
  let!(:recent_asset_no_file) { create(:asset) }

  # Let's check the 3 assets with files a bunch of times.
  let!(:twenty_checks) do
    (0..19).to_a.map do |x|
      the_asset = [old_asset, recent_asset_with_file_1, recent_asset_with_file_2][ x % 3 ]
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

  let(:report) { FixityReport.new }

  it "correctly counts the assets and fixity checks" do
    # OK we have 3 assets, with the a bunch of fixity checks attached to them.

    # These are, in REVERSE CHRON ORDER:
    # Most recent checks are first.
    expect(old_asset.fixity_checks.map{ |fc| fc.passed?}).to eq [true,  true, false, true, true,  true, false]
    expect(recent_asset_with_file_1.fixity_checks.map{ |fc| fc.passed?}).to eq [false, true, true,  true, true,  true, true]
    expect(recent_asset_with_file_2.fixity_checks.map{ |fc| fc.passed?}).to eq [true,  true, true,  true, false, true]

    # The report counts our 5 assets.
    expect(report.asset_count).to eq 5

    # old_asset, recent_asset_with_file_1 and recent_asset_with_file_2 failed their checks at some point in the past.
    # But the only one that should be reported as currently
    # failing is recent_asset_with_file_1, since its most recent check has failed.
    expect(report.bad_assets).to match_array([recent_asset_with_file_1])

    # All assets except recent_asset_no_file have files
    expect(report.stored_files).to eq 4

    # recent_asset_no_file has no stored file.
    expect(report.no_stored_files).to eq 1

    # Assets old_asset, recent_asset_with_file_1 and recent_asset_with_file_2 have checks.
    expect(report.with_checks).to eq 3

    # old_asset, recent_asset_with_file_1 and recent_asset_with_file_2 have recent checks
    expect(report.recent_checks).to eq 3

    # All the items with checks have recent ones.
    expect(report.stale_checks).to eq 0

    # All assets except old_asset are less than a week old.
    # Asset recent_asset_no_file doesn't have a file yet so we don't
    # care whether it's recent for fixity check purposes.
    # That leaves recent_asset_no_checks, recent_asset_with_file_1 and recent_asset_with_file_2.
    #expect(report.recent_files).to eq 3

    # All assets with checks have recent checks, but recent_asset_no_checks still needs to be checked.
    expect(report.no_checks_or_stale_checks).to eq 1

    # old_asset was ingested more than a day ago
    expect(report.not_recent_count).to eq 1

    # all but old_asset: recent_asset_no_checks, recent_asset_with_file_1, recent_asset_with_file_2, recent_asset_no_file
    expect(report.recent_count).to eq 4

    # Asset old_asset is not recent, but it's been checked this week.
    expect(report.not_recent_with_no_checks_or_stale_checks).to eq 0
  end

  describe "stale checks" do
    before do
      # New scenario:
      # Fixity checking has something wrong with it
      # and assets old_asset and recent_asset_with_file_1 have not been
      # checked for over a week. To simulate this, we just
      # get rid of their three most recent checks and rerun a report.
      old_asset.fixity_checks[0..2].each { |x| x.delete }
      recent_asset_with_file_1.fixity_checks[0..2].each { |x| x.delete }
      old_asset.reload
      recent_asset_with_file_1.reload
    end

    it "reports stale checks" do
      expect(old_asset.fixity_checks.map{ |fc| fc.passed?}).to eq [true, true, true, false]
      expect(recent_asset_with_file_1.fixity_checks.map{ |fc| fc.passed?}).to eq [true, true, true, true]
      expect(recent_asset_with_file_2.fixity_checks.map{ |fc| fc.passed?}).to eq [true,  true, true,  true, false, true]

      # In this scenario:
      # All assets with fixity checks have their most recent check passing.
      expect(report.bad_assets).to match_array([])

      # Still 4 assets.
      expect(report.asset_count).to eq 5

      # Four have stored files: recent_asset_no_checks, old_asset, recent_asset_with_file_1 and recent_asset_with_file_2.
      expect(report.stored_files).to eq 4

      #recent_asset_no_checks has no file.
      expect(report.no_stored_files).to eq 1

      # recent_asset_no_checks has no checks
      expect(report.no_checks).to eq 1

      # 3 have checks
      expect(report.with_checks).to eq 3

      # recent_asset_with_file_2 is now the only one with recent checks:
      expect(report.recent_checks).to eq 1

      # old_asset and recent_asset_with_file_1 have stale checks now
      expect(report.stale_checks).to eq 2

      # recent_asset_no_checks, recent_asset_with_file_1 and recent_asset_with_file_2 are recent assets with files.
      #expect(report.recent_files).to eq 3

      # recent_asset_no_checks (no checks yet) old_asset (checks stale) and recent_asset_with_file_1 (checks also stale) need to get checked.
      expect(report.no_checks_or_stale_checks).to eq 3

      # old_asset is only one ingested more than a day ago
      expect(report.not_recent_count).to eq 1

      # all but old_asset: recent_asset_no_checks, recent_asset_with_file_1, recent_asset_with_file_2, recent_asset_no_file
      expect(report.recent_count).to eq 4

      # Don't have any at present
      expect(report.not_recent_not_stored_count).to eq(0)

      # old_asset was ingested more than a day ago but it hasn't been checked for over a week.
      # Sound the alarm!
      expect(report.not_recent_with_no_checks_or_stale_checks).to eq 1
    end
  end

  describe "not_recent_not_stored_count" do
    let!(:recent_asset_no_file) { create(:asset) }
    let!(:old_asset_no_file) { create(:asset, created_at: Time.now() - 10000000)}
    let!(:recent_asset_file) { create(:asset_image_with_correct_sha512) }

    it "correctly reports" do
      expect(report.not_recent_not_stored_count).to eq(1)
    end
  end

  describe "stalest_current_fixity_check" do
    let(:oldest_current) { 1.year.ago.change(nsec: 0) } # avoid more precision than our db can store

    let!(:asset_with_file) {
      create(:asset_image_with_correct_sha512, fixity_checks: [build(:fixity_check, created_at: 1.day.ago)])
    }
    let!(:asset_with_oldest_current) {
      create(:asset_image_with_correct_sha512,
        fixity_checks: [
          build(:fixity_check, created_at: oldest_current),
          build(:fixity_check, created_at: oldest_current - 1.day)
        ])
    }

    it "finds" do
      expect(report.stalest_current_fixity_check.asset).to eq(asset_with_oldest_current)
      expect(report.stalest_current_fixity_check.timestamp).to eq(oldest_current)
    end
  end
end
