# This class digs up a bunch of stats about fixity
# (ensuring files haven't changed since we last looked at them)
# and pulls them into a report hash. This is then displayed in
# fixity_report.html.erb.
# The class is used in controllers/admin/assets_controller.rb .

class FixityReport
  # All assets, including collection thumbnail assets.
  def asset_count
    @asset_count ||= Asset.count
  end

  # All assets with stored files.
  def stored_files
    #@stored_files ||= count_asset_stats({stored_file: true})
    @stored_files ||= check_count_having([
      stored_file_sql
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

  # Assets with a file that have been checked in the past week.
  def recent_checks
    @recent_checks ||= check_count_having([
      stored_file_sql,
      "#{stale_checks_sql} = false"
    ])
  end

  # Assets with a file that *have* checks, but have not been checked for the past week.
  # Note: assets with no checks yet show up as nil in :stale_check column.
  def stale_checks
    @stale_checks ||= check_count_having([
      stored_file_sql,
      "#{stale_checks_sql} = true"
    ])
  end

  # Assets with files, that were ingested less than a week ago.
  def recent_files
    @recent_files ||= check_count_having([
      stored_file_sql,
      "#{recent_asset_sql} = true"
    ])
  end

  # Assets with files, that have no checks
  # or stale checks.
  # Because this is a left join,
  # :stale_check could be true
  #     (because the checks are stale),
  # or nil
  #     (because there are no checks yet.)
  def no_checks_or_stale_checks
    # @no_checks_or_stale_checks ||= count_asset_stats({
    #   stored_file: true,
    #   stale_check: [true, nil]
    # })
    @no_checks_or_stale_checks ||= check_count_having([
      "file_data ->> 'storage' = 'store'",
      "(#{stale_checks_sql} = true) OR (#{stale_checks_sql} is NULL)"
    ])
  end

  # See discussion of stale_check above.
  # Is this method name way too long?
  # Maybe, but the concept is kind of complex.
  def not_recent_with_no_checks_or_stale_checks
    # not_recent_with_no_checks_or_stale_checks ||= count_asset_stats({
    #   stored_file: true,
    #   recent_asset: false,
    #   stale_check: [true, nil]
    # } )
    @not_recent_with_no_checks_or_stale_checks ||= check_count_having([
      "file_data ->> 'storage' = 'store'",
      "#{recent_asset_sql} = false",
      "(#{stale_checks_sql} = true) OR (#{stale_checks_sql} is NULL)"
    ])
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

  def checks_are_stale_after
    return '7 days'
  end

  def asset_is_old_after
    return '7 days'
  end

  def stored_file_sql
    "file_data ->> 'storage' = 'store'"
  end

  def stale_checks_sql
    "(max(fixity_checks.created_at) < (NOW() - INTERVAL '#{checks_are_stale_after}'))"
  end

  def recent_asset_sql
    "(kithe_models.created_at > NOW() - INTERVAL '#{asset_is_old_after}')"
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