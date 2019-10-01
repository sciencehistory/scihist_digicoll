# Checks the SHA512 of _current_ stored file, compares against stored expected sha512,
# records the results of the check in FixityCheck ActiveRecord object. Also prunes old
# FixityCheck log records to keep only the interesting/useful ones, not complete history.
#
# FixityChecker.new(asset).check
#   This will check the asset, and log the results to the database.
#
# FixityChecker.new(asset).prune_checks
#   This will remove all the excess checks for the object so the database table
#   doesn't get too large.
#
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
      hash_function: 'SHA512',
      checked_uri: permanent_url,
      expected_result: expected_result,
      actual_result: actual_result,
      passed: (expected_result==actual_result)
    )
  end

  # FixityChecker.new(asset).prune_checks
  # Never throw out FAILED checks
  # Never throw out the earliest PASSED check
  # Always keep a PASSED check if it is preceded or followed by a failing check.
  # Always keep N most recent checks, whether passed or failed.
  def prune_checks
    checks = FixityCheck.checks_for(@asset, permanent_url).reorder("created_at asc")
    earliest_passing_check = nil
    0.upto(checks.length - NUMBER_OF_RECENT_PASSED_CHECKS_TO_KEEP).each do |i|
      if checks[i].passed? && earliest_passing_check.nil?
        earliest_passing_check = checks[i]
        next
      end
      next if checks[i].failed?
      next if i > 0 && checks[i - 1].failed?
      next if checks[i + 1].failed?
      checks[i].destroy
    end
  end

  private

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
