# This class digs up a bunch of stats about fixity
# (ensuring files haven't changed since we last looked at them)
# and pulls them into a report hash. This is then displayed in
# fixity_report.html.erb.
# The class is used in controllers/admin/assets_controller.rb .

class FixityReport < ViewModel

  valid_model_type_names "NilClass"

  def display
    report = {}
    # Did any checks fail?
    report[:bad_assets] = bad_assets.
      map { |row| Asset.find(row['asset_id']) }
    # General fixity stats:
    the_data = general_stats

    report[:asset_count]        = the_data.count

    report[:with_stored_files]  = the_data.count do |x|
      x[:stored_file] == true
    end

    report[:recent] = the_data.count do |x|
      x[:stored_file] == true &&
      x[:recent] == true
    end

    report[:with_checks] = the_data.count do |x|
      x[:stored_file] == true &&
      x[:check_count] > 0
    end

    report[:with_no_checks_or_stale_checks]  = the_data.count do |x|
      x[:stored_file] == true &&
      [true, nil].include?(x[:stale_check])
    end

    report[:not_recent_with_no_checks_or_stale_checks] = the_data.count do |x|
      x[:stored_file] == true &&
      x[:recent] == false  &&
      [true, nil].include?(x[:stale_check])
    end

    report
  end

  # Any assets whose most recent check has failed.
  # This query might get slow if we
  # accumulate a lot of failed checks.
  def bad_assets
    sql = """
      SELECT bad.asset_id FROM fixity_checks bad
      WHERE bad.passed = 'f'
      AND NOT EXISTS (
        SELECT FROM fixity_checks good
        WHERE good.asset_id = bad.asset_id
        AND good.passed = 't'
        AND good.created_at > bad.created_at )
    """
    ActiveRecord::Base.connection.execute(sql).to_a
  end

  def general_stats
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