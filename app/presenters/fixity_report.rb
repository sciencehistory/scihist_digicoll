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
    report[:bad_assets] = bad_assets.to_a.
      map { |row| Asset.find(row['asset_id']) }
    # General fixity stats:
    the_data = general_stats
    report[:asset_count]        = the_data.count
    report[:with_stored_files]  = the_data.count { |x| x[:stored_file] == true }
    report[:recent] = the_data.count { |x| x[:recent] == true }
    report[:with_checks] = the_data.count { |x| x[:check_count] > 0  }
    report[:with_stale_checks]  = the_data.count { |x| x[:stale_check] == true }
    report[:non_recent_with_stale_checks] = the_data.
      count { |x| x[:asset_is_recent] == false  &&  x[:stale_check] == true }
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
    ActiveRecord::Base.connection.execute(sql)
  end

  def general_stats
    checks_are_stale_after = '7 days'
    asset_is_old_after     = '7 days'
    data_we_need = {
      # We need the asset's ID to group the records.
      'id': 'kithe_models.id',
      # Does the asset have a file attached to it?
      'stored_file': "file_data ->> 'storage'",
      # How many checks does each asset have?
      'check_count': 'fixity_checks.count',
      # Is this asset due for a check?
      'stale_check': "max(fixity_checks.created_at) < NOW() - INTERVAL '#{checks_are_stale_after}'",
      # Has the asset been around for a while?
      'recent': "kithe_models.created_at > NOW() - INTERVAL '#{asset_is_old_after}'",
    }
    labels, sql_columns =
      data_we_need.keys, data_we_need.values
    Asset.
      left_outer_joins(:fixity_checks).
      group(:id).
      pluck(*sql_columns).
      map { |p| labels.zip(p).to_h }
  end
end