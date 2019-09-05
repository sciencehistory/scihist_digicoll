# FixityChecker.new(asset).check
# FixityChecker.new(asset).prune_checks
# This first version of the fixity checker only checks
# for actual discrepancies between already-recorded
# checksums and calculated ones.
#
# This means:
# Assets with nil files are ignored.
# Files with nil checksums are ignored.

class FixityChecker
  attr_reader :asset

  NUMBER_OF_RECENT_PASSED_CHECKS_TO_KEEP = 5

  # @param work [Work] Work object, it's members will be put into a zip
  # @param callback [proc], proc taking keyword arguments progress_i: and progress_total:, can
  #   be used to update a progress UI.
  def initialize(asset)
    raise ArgumentError.new("Please pass in an Asset.") unless asset.is_a? Asset
    @asset = asset
  end

  #FixityChecker.new(asset).check
  def check
    return nil if @asset.nil?
    return nil if @asset.file.nil?
    the_expected_checksum = expected_checksum
    # Note: @asset.file.sha512 can be nil on e.g.
    # items imported with DISABLE_BYTESTREAM_IMPORT=true
    # For now, we are ignoring these.
    return nil if the_expected_checksum.nil?

    new_check = FixityCheck.new(asset: @asset)
    new_check.expected_result = the_expected_checksum
    new_check.checked_uri = @asset.file.url
    new_check.actual_result = actual_checksum
    new_check.passed= (the_expected_checksum==actual_checksum)
    new_check.save!
  end

  #FixityChecker.new(asset).prune_checks
  def prune_checks
    return if @asset.file.nil?
    return if @asset.file.url.nil?
    checks_its_ok_to_delete.map(&:destroy)
  end

  private

  # Returns an array of checks that we don't want to keep.
  # The current rules are:
  # Never throw out FAILED checks
  # Never throw out the earliest PASSED check
  # Always keep N recent PASSED checks
  def checks_its_ok_to_delete
    checks = self.checks_for(@asset, @asset.file.url)
    return [] if checks.empty?
    # Throw all the passed checks INTO the trash.
    trash = checks.select { | ch | ch.passed? }
    # But then, pop the earliest passed check back OUT of the trash.
    earliest_passed_check = trash.pop
    # Finally, shift the most recent N passed checks back OUT of the trash.
    trash.shift(NUMBER_OF_RECENT_PASSED_CHECKS_TO_KEEP)
    return trash
  end

  def check_passed
  end

  def expected_checksum
    @asset.file.sha512
  end

  def actual_checksum
    sha_512 = nil
    @asset.file.open(rewindable: false) do | io_object |
      sha_512 = Shrine::Plugins::Signature::SignatureCalculator.
        new(:sha512, format: :hex).
        call(io_object)
    end
    sha_512
  end
end