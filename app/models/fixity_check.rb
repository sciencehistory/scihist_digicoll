# FixityCheck.check_asset(some_asset)
# This first version of fixity checking only checks
# for actual discrepancies between already-recorded
# checksums and calculated ones.
#
# This means:
# Assets with nil files are ignored.
# Files with nil checksums are ignored.

class FixityCheck < ApplicationRecord

  NUMBER_OF_RECENT_PASSED_CHECKS_TO_KEEP = 5

  belongs_to :asset
  validates_presence_of :asset

  def self.check(asset)
    raise ArgumentError.new("Please pass in an Asset.") unless asset.is_a? Asset
    self.new(asset: asset).run_check
  end

  # Returns in reverse chron order: first is most recent check.
  def self.checks_for(asset, checked_uri)
    FixityCheck.where(asset: asset, checked_uri: checked_uri).order('created_at desc, id desc')
  end

  def self.prune_checks(asset)
    return if asset.file.nil?
    return if asset.file.url.nil?
    byebug unless checks_its_ok_to_delete(asset).empty?
    self.checks_its_ok_to_delete(asset).map(&:destroy)
  end


  def failed?
    !passed?
  end

  def passed?
    passed
  end

  def run_check
    return nil if asset.nil?
    return nil if asset.file.nil?
    the_expected_checksum = expected_checksum
    # Note: asset.file.sha512 can be nil on e.g.
    # items imported with DISABLE_BYTESTREAM_IMPORT=true
    # For now, we are ignoring these.
    return nil if the_expected_checksum.nil?
    self.expected_result = the_expected_checksum
    self.checked_uri = asset.file.url
    self.actual_result = actual_checksum
    self.passed=(expected_result == actual_result)
    save!
  end

  private

  # Returns an array of checks that we don't want to keep.
  # The current rules are:
  # Never throw out FAILED checks
  # Never throw out the earliest PASSED check
  # Always keep N recent PASSED checks
  def self.checks_its_ok_to_delete(asset)
    checks = self.checks_for(asset, asset.file.url)
    return [] if checks.empty?
    # Throw all the passed checks INTO the trash.
    trash = checks.select { | ch | ch.passed? }
    # But then, pop the earliest passed check back OUT of the trash.
    earliest_passed_check = trash.pop
    # Finally, shift the most recent N passed checks back OUT of the trash.
    trash.shift(NUMBER_OF_RECENT_PASSED_CHECKS_TO_KEEP)
    return trash
  end

  def expected_checksum
    asset.file.sha512
  end

  def actual_checksum
    sha_512 = nil
    asset.file.open(rewindable: false) do | io_object |
      sha_512 = Shrine::Plugins::Signature::SignatureCalculator.
        new(:sha512, format: :hex).
        call(io_object)
    end
    sha_512
  end
end
