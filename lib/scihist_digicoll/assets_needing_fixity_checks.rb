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
      raise ArgumentError.new("cycle_length must be integer") unless cycle_length.kind_of?(Integer)
      @cycle_length = cycle_length
    end

    def asset_ids_to_check
      return Asset.all.pluck(:id) if cycle_length == 0
      sifted_asset_ids
    end

    def expected_num_to_check
      @expected_num_to_check ||= Asset.count / cycle_length
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

    def selected_asset_ids
      selected_assets_scope.pluck("kithe_models.id")
    end
  end
end
