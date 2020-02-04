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
    BATCH_FETCH_SIZE = 1000
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

    # Gives you a way to iterate over all assets to check. You can call it with a block:
    #
    #     assets_needing.assets_to_check { |asset_model| ... }
    #
    # But using some ruby Enumerator cleverness, you can call it without a block to get an
    # Enumerator back, which lets you chain methods like `each_slice` onto it, which is actually
    # what our intended caller does.
    #
    # The implementation fetches 1000 (BATCH_FETCH_SIZE) of the Assets with stalest
    # fixity checks in; and keeps doing that in batches of 1000 until all the assets
    # we desire to fetch (based on total number of assets divide by CYCLE_LENGTH) have
    # been fetched.
    #
    # This weird implementation is needed to avoid fetching everything into memory at once,
    # without using ActiveRecord's `find_each` batching, becuase previous attempts
    # to use `find_each` seemed to run into trouble with race-conditions caused by editing the database
    # to add fixity checks records, in a way that affected the conditions of the `find_each`,
    # and may have resulted in ending up checking everything. The trick here is to avoid
    # fetching everything into memory, including huge lists of IDs, or making SQL involving
    # lists of hundreds/thousands of IDs, while still batching fetching multipe objects
    # per SQL select.
    def assets_to_check
      # Clever way to return an enumerator that can be chained
      # https://blog.arkency.com/2014/01/ruby-to-enum-for-enumerator
      return to_enum(:assets_to_check) unless block_given?


      fetched = 0
      while (fetched < expected_num_to_check)
        num_to_fetch = ((expected_num_to_check - fetched) >= BATCH_FETCH_SIZE) ? BATCH_FETCH_SIZE : (expected_num_to_check - fetched)

        selected_assets_scope(limit: num_to_fetch).each do |record|
          yield record
        end
        fetched += num_to_fetch
      end
    end

    def expected_num_to_check
      @expected_num_to_check ||= (cycle_length == 0 ? Asset.count : Asset.count / cycle_length)
    end

    private

    # ActiveRecord scope for those Assets most in need of fixity checks -- either
    # they don't have a fixity check on record, or their most recent fixity check
    # is among the oldest in the database.
    #
    # Applying this sort is a bit tricky because of the one-to-many relationship
    # between Asset and fixity check, and need to order by _most recent_ fixity
    # check recorded.
    def selected_assets_scope(limit:)
      Asset.
        left_outer_joins(:fixity_checks).
        group(:id).
        order(Arel.sql "max(fixity_checks.created_at) nulls first").
        limit(limit)
    end
  end
end
