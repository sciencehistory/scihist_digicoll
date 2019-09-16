# FixityChecker.new(asset).check
#   This will check the asset, and log the results to the database.
#
# FixityChecker.new(asset).prune_checks
#   This will remove all the excess checks for the object so the database table
#   doesn't get too large.

class FixityChecker
  attr_reader :asset

  NUMBER_OF_RECENT_PASSED_CHECKS_TO_KEEP = 5

  # Creating a FixityChecker.new(asset) doesn't actually do anything.
  def initialize(asset)

    raise ArgumentError.new("Please pass in an Asset.") if asset.nil?

    raise ArgumentError.new("Please pass in an Asset.") unless asset.is_a? Asset

    raise ArgumentError.new(
        "#{asset.friendlier_id} has no file associated with it, so we can't run a check on it."
    ) if asset.file.nil?

    raise ArgumentError.new(
        "#{asset.friendlier_id} has no stored checksum, so we can't run a check on it."
    ) if asset.file.sha512.nil?

    @asset = asset
  end

  # FixityChecker.new(asset).check
  def check
    FixityCheck.create!(
      asset: @asset,
      hash_function: 'SHA-512',
      checked_uri: permanent_url,
      expected_result: expected_result,
      actual_result: actual_result,
      passed: (expected_result==actual_result)
    )
  end

  #FixityChecker.new(asset).prune_checks
  # After pruning, for each asset - URI combination, you will be left with:
  # up to NUMBER_OF_RECENT_PASSED_CHECKS_TO_KEEP recent passed checks,
  # plus all the failed checks,
  # plus one initial check (to remember the file that was intially uploaded.)
  def prune_checks
    checks_to_delete.map(&:destroy)
  end

  private

  # Returns an array of checks that we don't want to keep.
  # The current rules are:
  # Never throw out FAILED checks
  # Never throw out the earliest PASSED check
  # Always keep N recent PASSED checks
  def checks_to_delete
    # Throw all the passed checks INTO the trash.
    checks = FixityCheck.checks_for(@asset, permanent_url)
    return [] if checks.empty?
    trash = checks.select { | ch | ch.passed? }
    # But then, pop the earliest passed check back OUT of the trash.
    earliest_passed_check = trash.pop
    # Finally, shift the most recent N passed checks back OUT of the trash.
    recent_passed_checks = trash.shift(NUMBER_OF_RECENT_PASSED_CHECKS_TO_KEEP)
    return trash
  end

  def expected_result
    @expected_result ||= @asset.file.sha512
  end

  # Note: this recipe is copied from:
  # https://github.com/shrinerb/shrine/blob/1f67da86ba028c0464d80fd0a8c9bd4d9aec20be/lib/shrine/plugins/signature.rb#L101 .
  # Thanks to janko for this.
  def actual_result
    @actual_result ||= begin
      @asset.file.open(rewindable:false) do |io|
        digest = Digest::SHA512.new
        digest.update(io.read(16*1024, buffer ||= String.new)) until io.eof?
        digest.hexdigest
      end
    rescue Aws::S3::Errors::NotFound, Errno::ENOENT
      "[file missing]"
    end
  end

  # @asset.file.url is not actually what we want here.
  # For instance, if the file is on S3 and shrine doesn't think it's a public ACL,
  # file.url would return a time-limited signed S3 URL which won't actually be accessible
  # in the far future. So we use this instead.
  def permanent_url
    @asset.file.url(public: true)
  end
end
