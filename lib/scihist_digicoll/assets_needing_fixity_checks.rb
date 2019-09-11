module ScihistDigicoll
  module AssetsNeedingFixityChecks
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
    def self.assets_to_check(cycle_length=7)
      asset_ids = if cycle_length == 0
        Asset.all.pluck(:id)
      else
        sifted_asset_ids(cycle_length)
      end
      asset_ids.each do |id|
        yield Asset.find(id)
      end
    end

    private

    def self.sifted_asset_ids(cycle_length)
      number_to_fetch = Asset.count / cycle_length
      sql = """
        SELECT kithe_models.id
        FROM kithe_models
        LEFT JOIN fixity_checks
        ON kithe_models.id = fixity_checks.asset_id
        WHERE kithe_models.type = 'Asset'
        GROUP BY kithe_models.id
        ORDER BY max(fixity_checks.created_at) nulls first
        LIMIT #{number_to_fetch};
      """
      ActiveRecord::Base.connection.
        exec_query(sql).
        rows.map(&:first)
    end
  end
end