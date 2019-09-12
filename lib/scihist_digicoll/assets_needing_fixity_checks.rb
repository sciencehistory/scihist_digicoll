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

    attr_reader :cycle_length

    # @param cycle_length [Integer] We will prepare for checking 1/cycle_length
    # assets, the ones most in need of checking (cause they have no checks on record
    # or oldest checks on record). The idea is you want all assets to be checked weekly,
    # you run nightly with cycle_length 7. Which is the default. `0` means "all assets".
    def initialize(cycle_length=7)
      @cycle_link = cycle_length
    end

    def asset_ids_to_check
      return Asset.all.pluck(:id) if cycle_length == 0
      sifted_asset_ids(cycle_length)
    end

    def expected_num_to_check
      @expected_num_to_check ||= Asset.count / cycle_length
    end

    private

    def sifted_asset_ids
      sql = """
        SELECT kithe_models.id
        FROM kithe_models
        LEFT JOIN fixity_checks
        ON kithe_models.id = fixity_checks.asset_id
        WHERE kithe_models.type = 'Asset'
        GROUP BY kithe_models.id
        ORDER BY max(fixity_checks.created_at) nulls first
        LIMIT #{expected_num_to_check};
      """
      ActiveRecord::Base.connection.
        exec_query(sql).
        rows.map(&:first)
    end
  end
end
