# This class digs up a bunch of stats about fixity
# (ensuring files haven't changed since we last looked at them)
# and pulls them into a report hash. This is then displayed in
# fixity_report.html.erb.
# The class is used in controllers/admin/assets_controller.rb .

class FixityReport
  # If no fixity check no older than STALE_IN_DAYS, considered stale
  STALE_IN_DAYS = ScihistDigicoll::AssetsNeedingFixityChecks::DEFAULT_PERIOD_IN_DAYS
  # Assets older than EXPECTED_FRESH_IN_DAYS should not be stale, or it's a problem.
  EXPECTED_FRESH_IN_DAYS = 1

  # All assets, including collection thumbnail assets.
  def asset_count
    @asset_count ||= Asset.count
  end

  def not_recent_count
    @not_recent_count ||= Asset.where("#{recent_asset_sql} = false").count
  end

  def not_recent_not_stored_count
    @not_recent_not_stored_count ||= Asset.where("#{recent_asset_sql} = false").where(not_stored_file_sql).count
  end

  # All assets with stored files.
  def stored_files
    @stored_files ||= Asset.where(stored_file_sql).count
  end

  # Assets with a file that have been checked in the past week.
  def recent_checks
     @recent_checks ||= check_count_having([
       stored_file_sql, "#{stale_checks_sql} = false"
     ])
  end

  # Assets with no stored files, which obviously can't
  # be checked for fixity.
  # Note: asset_stats reports these as null.
  # Note: this could also be count_asset_stats ({stored_file: [false, nil]}).
  def no_stored_files
    @no_stored_files ||= asset_count - stored_files
  end

  # Assets with a file stored on them, but which haven't
  # had a fixity check yet.
  def no_checks
    @no_checks ||= check_count_having([
      stored_file_sql,
      "fixity_checks.count = 0"
    ])
  end

  # Assets with a file and at least one fixity check.
  def with_checks
    @with_checks ||= stored_files - no_checks
  end

  # Assets with a file that *have* checks, but have not been checked for the past week.
  # Note: assets with no checks yet show up as nil, so stale_checks + recent_checks != with_checks
  def stale_checks
    @stale_checks ||= check_count_having([
      stored_file_sql, "#{stale_checks_sql}"
    ])
  end

  def recent_count
    @recent_count ||= Asset.where(recent_asset_sql).count
  end

  def earliest_check_date
    @earliest_check_date ||= FixityCheck.minimum(:created_at).in_time_zone
  end

  def latest_check_date
    @latest_check_date ||= FixityCheck.maximum(:created_at).in_time_zone
  end

  # Assets with files, that were ingested less than a week ago.
  # def recent_files
  #   @recent_files ||= check_count_having([
  #     stored_file_sql, recent_asset_sql
  #   ])
  # end

  # Assets with files, that have no checks
  # or stale checks.
  # Because this is a left join,
  # :stale_check could be true
  #     (because the checks are stale),
  # or nil
  #     (because there are no checks yet.)
  def no_checks_or_stale_checks
    @no_checks_or_stale_checks ||= check_count_having([
      stored_file_sql,
      "(#{stale_checks_sql}) OR (#{stale_checks_sql} is NULL)"
    ])
  end

  # See discussion of stale_check above.
  # Is this method name way too long?
  # Maybe, but the concept is kind of complex.
  def not_recent_with_no_checks_or_stale_checks
    @not_recent_with_no_checks_or_stale_checks ||= check_count_having([
      stored_file_sql,
      "#{recent_asset_sql} = false",
      "(#{stale_checks_sql}) OR (#{stale_checks_sql} is NULL)"
    ])
  end


  # an ActiveRecord relation corresponding to #not_recent_with_no_checks_or_stale_checks, but
  # returning a relation you can get actual assets from, not just count.
  def need_checks_assets_relation
    build_query([
      stored_file_sql,
      "#{recent_asset_sql} = false",
      "(#{stale_checks_sql}) OR (#{stale_checks_sql} is NULL)"
    ], count_only: false)
  end




  # Of the assets that have fixity checks, which has the OLDEST most recent
  # check, and what is it?
  #
  # We return an OpenStruct with `asset` and `timestamp` for the asset with
  # the oldest most recent fixity check. Can both be null if there are no fixity
  # checks.
  #
  # This is some tricky SQL, but we think we got it right.
  def stalest_current_fixity_check
    @stalast_current_fixity_check ||= begin
      # We think this does what we want in SQL...
      (pk, timestamp) = Asset.left_outer_joins(:fixity_checks).group(:id).
                          having(stored_file_sql).
                          order(Arel.sql "max(fixity_checks.created_at)").
                          limit(1).
                          maximum("fixity_checks.created_at").first.to_a

      OpenStruct.new(asset: (Asset.find(pk) if pk), timestamp: timestamp&.in_time_zone)
    end
  end


  # Any assets whose most recent check has failed.
  # This query might get slow if we
  # accumulate a lot of failed checks.
  # This method contacts the DB twice,
  # once to get the asset ids, and once
  # to load the assets into memory. Oh well.
  def bad_assets
    @bad_assets ||= begin
      sql = """
        SELECT bad.asset_id FROM fixity_checks bad
        WHERE bad.passed = 'f'
        AND NOT EXISTS (
          SELECT FROM fixity_checks good
          WHERE good.asset_id = bad.asset_id
          AND good.passed = 't'
          AND good.created_at > bad.created_at )
      """
      results = ActiveRecord::Base.connection.execute(sql)
      asset_ids = results.to_a.map {|row| row['asset_id']}
      Asset.find(asset_ids)
    end
  end

  private


  def not_stored_file_sql
    "file_data ->> 'storage' != 'store' or file_data ->> 'storage' is NULL"
  end

  def stored_file_sql
    "file_data ->> 'storage' = 'store'"
  end

  def stale_checks_sql
    "(max(fixity_checks.created_at) < (NOW() - INTERVAL '#{STALE_IN_DAYS} days'))"
  end

  def recent_asset_sql
    "(kithe_models.created_at > (NOW() - INTERVAL '#{EXPECTED_FRESH_IN_DAYS} days'))"
  end

  def check_count_having(conditions)
    build_query(conditions, count_only: true)
  end

  def build_query(conditions, count_only:false)
    subquery = Asset.
      select("kithe_models.id").
      left_outer_joins(:fixity_checks).
      group(:id)
    conditions.each do |h|
      subquery = subquery.having(h)
    end
    relation = Asset.where(id: subquery)

    if count_only
      relation.count
    else
      relation
    end
  end
end
