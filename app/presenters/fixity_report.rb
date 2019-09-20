# This class digs up a bunch of stats about fixity
# (ensuring files haven't changed since we last looked at them)
# and pulls them into a report hash. This is then displayed in
# fixity_report.html.erb.
# The class is used in controllers/admin/assets_controller.rb .

class FixityReport < ViewModel

  valid_model_type_names "NilClass"

  # All assets, including collection thumbnail assets.
  def asset_count
    asset_stats.count
  end

  # All assets with stored files.
  def stored_files
    asset_stats.count do |x|
      x[:stored_file] == true
    end
  end

  # Assets with no stored files, which obviously can't
  # be checked for fixity.
  # Note: asset_stats reports these as null.
  def no_stored_files
    asset_stats.count do |x|
      x[:stored_file] != true
    end
  end

  # Assets with a file stored on them, but which haven't
  # had a fixity check yet.
  def no_checks
    asset_stats.count do |x|
      x[:stored_file] == true &&
      x[:check_count] == 0
    end
  end

  # Assets with a file and at least one fixity check.
  def with_checks
    asset_stats.count do |x|
      x[:stored_file] == true &&
      x[:check_count] > 0
    end
  end


  def recent_checks
    asset_stats.count do |x|
      x[:stored_file] == true &&
      x[:stale_check] == false
    end
  end

  def stale_checks
    asset_stats.count do |x|
      x[:stored_file] == true &&
      x[:stale_check] == true
    end
  end

  def recent_files
    asset_stats.count do |x|
      x[:stored_file] == true &&
      x[:recent] == true
    end
  end

  def no_checks_or_stale_checks
    asset_stats.count do |x|
      x[:stored_file] == true &&
      [true, nil].include?(x[:stale_check])
    end
  end

  def not_recent_with_no_checks_or_stale_checks
    asset_stats.count do |x|
      x[:stored_file] == true &&
      x[:recent] == false  &&
      [true, nil].include?(x[:stale_check])
    end
  end

  def display
    {
      bad_assets: bad_assets,
      asset_count: asset_stats.count,
      stored_files: stored_files,
      no_stored_files: no_stored_files,
      with_checks: with_checks,
      no_checks: no_checks,
      recent_checks: recent_checks,
      stale_checks: stale_checks,
      recent_files: recent_files,
      no_checks_or_stale_checks: no_checks_or_stale_checks,
      not_recent_with_no_checks_or_stale_checks: not_recent_with_no_checks_or_stale_checks
    }
  end

  # Any assets whose most recent check has failed.
  # This query might get slow if we
  # accumulate a lot of failed checks.
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
      ActiveRecord::Base.connection.execute(sql).to_a.
        map { |row| Asset.find(row['asset_id']) }
    end
  end

  def asset_stats
    @asset_stats ||= begin
      checks_are_stale_after = '7 days'
      asset_is_old_after     = '7 days'

      data_we_need = {
        # We need the asset's ID to group the records.
        'id': 'kithe_models.id',
        # For debugging:
        'friendlier_id': 'kithe_models.friendlier_id',
        # Does the asset have a file attached to it?
        'stored_file': "file_data ->> 'storage'",
        # How many checks does each asset have?
        'check_count': 'fixity_checks.count',
        # Is this asset due for a check? # (NULL counts as TRUE) here.
        'stale_check': "max(fixity_checks.created_at) < NOW() - INTERVAL '#{checks_are_stale_after}'",
        # Is the asset "recent" ?
        'recent': "kithe_models.created_at > NOW() - INTERVAL '#{asset_is_old_after}'",
      }
      labels = data_we_need.keys

      sql_columns = data_we_need.values.
        map { |x| Arel.sql(x) }

      Asset.
        left_outer_joins(:fixity_checks).
        group(:id).
        pluck(*sql_columns).
        map { |p| labels.zip(p).to_h }
    end
  end
end