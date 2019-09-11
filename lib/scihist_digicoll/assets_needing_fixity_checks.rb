module ScihistDigicoll
  module AssetsNeedingFixityChecks
    # This recipe is used in check_fixity.rake .
    #
    # Running fixity checks takes a while, so we want to spread
    # the job out over a week or so. The current recipe will:
    #
    #  * Check all the assets if you run the rake task 7 times.
    #  * Check the same number of assets every day.
    #  * Not load the assets into memory; that job falls to the rake task.
    #
    # asset_ids tries to find the ids for the assets that need to
    # be checked the most urgently.
    #
    # Assets with NO CHECK on record at all are picked first.
    # Then come assets whose MOST RECENT CHECK is the OLDEST.
    #
    # If you run the check once a day, the items will be checked
    # roughly once a week if length_of_cycle == 7.
    def self.asset_ids_to_check(length_of_cycle=7)
      number_to_fetch = Asset.count / length_of_cycle
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
        rows.map { |r| r.first }
    end
  end
end
