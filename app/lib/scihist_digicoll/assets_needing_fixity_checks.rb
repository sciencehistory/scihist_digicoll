module ScihistDigicoll
  # This recipe is used in check_fixity.rake .
  #
  # Running fixity checks takes a while, so we want to spread
  # the job out over a week or so. The current recipe will:
  #
  #  * Check all the assets if you run the rake task 7 times.
  #  * Check the same number of assets every day.
  #
  # asset_ids tries to find the ids for the assets that need to
  # be checked the most urgently.
  #
  # Assets with NO CHECK on record at all are picked first.
  # Then come assets whose MOST RECENT CHECK is the OLDEST.
  #
  # If you run the check once a day, the items will be checked
  # roughly once a week if cycle_length == 7.
  #
  # Note: if you pass in 0 as the cycle length, you just get all the assets.
  #
  class AssetsNeedingFixityChecks
    # In a constnat used in our whenever cron schedule, that can also be used
    # in text describing fixity configuration to staff.
    WHENEVER_CRON_TIME = '2:30 am'
    DEFAULT_PERIOD_IN_DAYS  = 7 # in days
    attr_reader :cycle_length

    # @param cycle_length [Integer] We will prepare for checking 1/cycle_length
    # assets, the ones most in need of checking (cause they have no checks on record
    # or oldest checks on record). The idea is you want all assets to be checked weekly,
    # you run nightly with cycle_length 7. Which is the default. `0` means "all assets".
    def initialize(cycle_length=DEFAULT_PERIOD_IN_DAYS)
      raise ArgumentError.new("cycle_length must be integer") unless cycle_length.kind_of?(Integer)
      @cycle_length = cycle_length
    end

    def assets_to_check
      # We need to use sub-query, cause find_each needs it's own ORDER BY, to
      # be able to fetch in batches reliably.
      Asset.where(id: selected_assets_scope).find_each
    end

    def expected_num_to_check
      @expected_num_to_check ||= (cycle_length == 0 ? Asset.count : Asset.count / cycle_length)
    end

    private

    def selected_assets_scope
      Asset.
        select("kithe_models.id").
        left_outer_joins(:fixity_checks).
        group(:id).
        order(Arel.sql "max(fixity_checks.created_at) nulls first").
        limit(expected_num_to_check)
    end
  end
end
