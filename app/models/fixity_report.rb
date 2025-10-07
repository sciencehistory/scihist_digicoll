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

  # We store video originals in 'video_store' and everything else in 'store'.
  NOT_STORED_FILE_SQL = "(file_data ->> 'storage' NOT IN ('store', 'video_store') or file_data ->> 'storage' is NULL)"
  STORED_FILE_SQL     = "(file_data ->> 'storage' IN ('store','video_store'))"
  STALE_CHECKS_SQL    = "(max(fixity_checks.created_at) < (NOW() - INTERVAL '#{STALE_IN_DAYS} days'))"
  RECENT_ASSET_SQL    = "(kithe_models.created_at > (NOW() - INTERVAL '#{EXPECTED_FRESH_IN_DAYS} days'))"
  REPORT_CACHE_KEY = "scihist:fixity_report"
  HOW_LONG_TO_CACHE_REPORT = 1.days


  def recalculate_report
    Rails.cache.delete(REPORT_CACHE_KEY)
    latest_report
  end

  def report_from_cache
    Rails.cache.fetch(REPORT_CACHE_KEY, expires_in: HOW_LONG_TO_CACHE_REPORT)
  end


  def report_hash
    rep = {}


    rep[:asset_count]      = Asset.count
    rep[:recent_count]     = Asset.where(RECENT_ASSET_SQL).count
    rep[:not_recent_count] = Asset.where("#{RECENT_ASSET_SQL} = false").count
    rep[:stored_files]     = Asset.count(STORED_FILE_SQL)

    rep[:no_checks]     = check_count_having([STORED_FILE_SQL, "fixity_checks.count = 0"])
    rep[:recent_checks] = check_count_having([ STORED_FILE_SQL, "#{STALE_CHECKS_SQL} = false" ])
    rep[:stale_checks]  = check_count_having([ STORED_FILE_SQL, STALE_CHECKS_SQL ])

    rep[:no_stored_files] = rep[:asset_count]  - rep[:stored_files]
    rep[:with_checks]     = rep[:stored_files] - rep[:no_checks]


    rep[:not_recent_not_stored_count] = Asset.where("#{RECENT_ASSET_SQL} = false").where(NOT_STORED_FILE_SQL).count

    rep[:earliest_check_date] = FixityCheck.minimum(:created_at).in_time_zone
    rep[:latest_check_date]   = FixityCheck.maximum(:created_at).in_time_zone


    # Note the left join.
    # STALE_CHECKS_SQL could be true
    #   (because the checks are stale),
    # or nil
    #   (because there are no checks yet.)
    rep[:no_checks_or_stale_checks]  = check_count_having([
      STORED_FILE_SQL,
      "(#{STALE_CHECKS_SQL}) OR (#{STALE_CHECKS_SQL} is NULL)"
    ])

    rep[:not_recent_with_no_checks_or_stale_checks] = check_count_having([
      STORED_FILE_SQL,
      "#{RECENT_ASSET_SQL} = false",
      "(#{STALE_CHECKS_SQL}) OR (#{STALE_CHECKS_SQL} is NULL)"
    ])


    # Stalest:
    (pk, timestamp) = Asset.left_outer_joins(:fixity_checks).group(:id).
                        having(STORED_FILE_SQL).
                        order(Arel.sql "max(fixity_checks.created_at)").
                        limit(1).
                        maximum("fixity_checks.created_at").first.to_a
    rep[:stalest_current_fixity_check_asset_id] = pk
    rep[:stalest_current_fixity_check_timestamp] = timestamp&.in_time_zone

    # Any assets whose most recent check has failed.
    # This query will get slow if we
    # accumulate a lot of failed checks.
    rep[:bad_asset_ids]    = ActiveRecord::Base.connection.execute("""
      SELECT bad.asset_id FROM fixity_checks bad
      WHERE bad.passed = 'f'
      AND NOT EXISTS (
        SELECT FROM fixity_checks good
        WHERE good.asset_id = bad.asset_id
        AND good.passed = 't'
        AND good.created_at > bad.created_at )
    """).to_a.map {|row| row['asset_id']}

    rep[:timestamp] = Time.current.to_s

    rep

  end

  # This method will be moved out of this class in a future refactor:
  def need_checks_assets_relation
    stored_file  = FixityReport::STORED_FILE_SQL
    recent_asset = FixityReport::RECENT_ASSET_SQL
    stale_check  = FixityReport::STALE_CHECKS_SQL

    Asset.where(
      id: Asset.select("kithe_models.id").
        left_outer_joins(:fixity_checks).group(:id).having(stored_file).
        having("#{recent_asset} = false").
        having("(#{stale_check}) OR (#{stale_check} is NULL)")
    )
  end


  private

  def latest_report
    Rails.cache.fetch(REPORT_CACHE_KEY, expires_in: HOW_LONG_TO_CACHE_REPORT) { report_hash }
  end

  def check_count_having(conditions)
    subquery = Asset.
      select("kithe_models.id").
      left_outer_joins(:fixity_checks).
      group(:id)
    conditions.each do |h|
      subquery = subquery.having(h)
    end
    Asset.where(id: subquery).count
  end
end
