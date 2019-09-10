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
  CHECK_CYCLE_LENGTH = 7


  # @param work [Work] Work object, it's members will be put into a zip
  # @param callback [proc], proc taking keyword arguments progress_i: and progress_total:, can
  #   be used to update a progress UI.
  def initialize(asset)
    raise ArgumentError.new("Please pass in an Asset.") unless asset.is_a? Asset
    @asset = asset
  end

  #FixityChecker.new(asset).check
  def check(sieve_integer = 0)
    return unless sift(sieve_integer)
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
  # After pruning, for each asset - URI combination, you will be left with:
  # up to NUMBER_OF_RECENT_PASSED_CHECKS_TO_KEEP recent passed checks,
  # plus all the failed checks,
  # plus one initial check (to remember the file that was intially uploaded.)
  def prune_checks(sieve_integer = 0)
    return unless sift(sieve_integer)
    return if @asset.file.nil?
    return if @asset.file.url.nil?
    checks_its_ok_to_delete.map(&:destroy)
  end

  def all_passed?
    checks_for_this_uri.all?{ |ch| ch.passed? }
  end

  def check_count_humanized
    n = checks_for_this_uri.count
    return "Never checked" if n == 0
    return "Checked once" if n == 1
    "Checked #{n} times"
  end

  def check_count
    checks_for_this_uri.count
  end

  def oldest_check
    checks_for_this_uri.last.created_at
  end

  def newest_check
    checks_for_this_uri.first.created_at
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

  # A memoized list of checks for this asset's current file.
  # Used for reporting on a particular asset on the asset view page
  # without fetching the info more than once.
  def checks_for_this_uri
    return [] if @asset.file.nil?
    return [] if @asset.file.url.nil?
    @checks_for_this_uri ||= FixityCheck.checks_for(@asset, @asset.file.url)
  end

  def expected_checksum
    @asset.file.sha512
  end


  # Sifts all our  assets by some integer
  # between one and CHECK_CYCLE_LENGTH.
  # Allows us to convieniently check only a subset of
  # the assets at a time, but be sure everything eventually
  # gets checked.
  # Pass in 0, and everything will go through the sieve.
  def sift(sieve_integer)
    return true if sieve_integer == 0
    check_sieve(sieve_integer)
    @asset.friendlier_id.bytes.sum % CHECK_CYCLE_LENGTH == sieve_integer
  end

  # Check this is a positive int between 1 and the cycle length.
  def check_sieve(sieve_integer)
    if !(sieve_integer.is_a? Integer)        ||
      sieve_integer < 1                      ||
      sieve_integer > CHECK_CYCLE_LENGTH
      raise ArgumentError.new(
        "Expected a positive int between  1 and #{CHECK_CYCLE_LENGTH}. Got #{sieve_integer}"
      )
    end
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