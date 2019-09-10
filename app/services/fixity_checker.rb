# FixityChecker.new(asset).check
#   This will check the asset, and log the results to the database.
#
# FixityChecker.new(asset).prune_checks
#   This will remove all the excess checks for the object so the database table
#   doesn't get too large.
#
# Assets with nil files are ignored.

class FixityChecker
  attr_reader :asset

  NUMBER_OF_RECENT_PASSED_CHECKS_TO_KEEP = 5


  # Creating a FixityChecker.new(asset) doesn't actually do anything.
  def initialize(asset)
    raise ArgumentError.new("Please pass in an Asset.") unless asset.is_a? Asset

    raise ArgumentError.new(
        "#{@asset.friendlier_id} has no file associated with it, so we can't run a check on it."
    ) if asset.file.nil?

    raise ArgumentError.new(
        "#{@asset.friendlier_id} has no stored checksum, so we can't run a check on it."
    ) if asset.file.sha512.nil?

    @asset = asset
  end

  #FixityChecker.new(asset).check
  def check
    the_expected_checksum = expected_checksum
    new_check = FixityCheck.new(asset: @asset)
    new_check.expected_result = the_expected_checksum
    new_check.checked_uri = @asset.file.url
    new_check.actual_result = actual_checksum
    new_check.passed= (the_expected_checksum==actual_checksum)
    new_check.save!
  end

  #FixityChecker.new(asset).prune_checks
  # After pruning, for each asset - URI combination, you will be left with:
  # up to NUMBER_OF_RECENT_PASSED_CHECKS_TO_KEEP recent passed checks,
  # plus all the failed checks,
  # plus one initial check (to remember the file that was intially uploaded.)
  def prune_checks
    checks_its_ok_to_delete.map(&:destroy)
  end

  private

  # Returns an array of checks that we don't want to keep.
  # The current rules are:
  # Never throw out FAILED checks
  # Never throw out the earliest PASSED check
  # Always keep N recent PASSED checks
  def checks_its_ok_to_delete
    # Throw all the passed checks INTO the trash.
    checks = FixityCheck.checks_for(@asset, @asset.file.url)
    return [] if checks.empty?
    trash = checks.select { | ch | ch.passed? }
    # But then, pop the earliest passed check back OUT of the trash.
    earliest_passed_check = trash.pop
    # Finally, shift the most recent N passed checks back OUT of the trash.
    recent_passed_checks = trash.shift(NUMBER_OF_RECENT_PASSED_CHECKS_TO_KEEP)
    return trash
  end

  def expected_checksum
    @asset.file.sha512
  end

  def actual_checksum
    sha512 = Digest::SHA512.new
    @asset.file.open(rewindable:false) do |io|
      if io.is_a? File
        sha512.file io
      else
        io.each_chunk do |chunk|
          sha512 << chunk
        end
      end
    end
    sha512.hexdigest
  end
end