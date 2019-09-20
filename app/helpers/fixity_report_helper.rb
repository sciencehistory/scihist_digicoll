# This class digs up a bunch of stats about fixity
# (ensuring files haven't changed since we last looked at them)
# and pulls them into a report hash. This is then displayed in
# fixity_report.html.erb.
# The class is used in controllers/admin/assets_controller.rb .
module FixityReportHelper
  class FixityReportHelper
    # All assets, including collection thumbnail assets.
    def asset_count
      @asset_count ||= asset_stats.count
    end

    # All assets with stored files.
    def stored_files
      @stored_files ||= count_asset_stats ({stored_file: true})
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
      @no_checks ||= count_asset_stats ({stored_file: true, check_count: 0})
    end

    # Assets with a file and at least one fixity check.
    def with_checks
      @with_checks ||= stored_files - no_checks
    end

    # Assets with a file that have been checked in the past week.
    def recent_checks
      @recent_checks ||= count_asset_stats ({stored_file: true, stale_check: false})
    end

    # Assets with a file that *have* checks, but have not been checked for the past week.
    # Note: assets with no checks yet show up as nil in :stale_check column.
    def stale_checks
      @stale_checks ||= count_asset_stats ({stored_file: true, stale_check: true})
    end

    # Assets with files, that were ingested less than a week ago.
    def recent_files
      @recent_files ||= count_asset_stats ({stored_file: true, recent_asset: true})
    end

    # Assets with files, that have no checks
    # or stale checks.
    # Because this is a left join,
    # :stale_check could be true
    #     (because the checks are stale),
    # or nil
    #     (because there are no checks yet.)
    def no_checks_or_stale_checks
      @no_checks_or_stale_checks ||= count_asset_stats ({
        stored_file: true,
        stale_check: [true, nil]
      })
    end

    # see above.
    # Is this method name way too long?
    # Maybe, but the concept is kind of complex.
    def not_recent_with_no_checks_or_stale_checks
      not_recent_with_no_checks_or_stale_checks ||= count_asset_stats ({
        stored_file: true,
        recent_asset: false,
        stale_check: [true, nil]
      } )
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

    private

    # Count how many rows of asset_stats
    # meet all the required conditions.
    def count_asset_stats(conditions)
      asset_stats.count do |row_hash|
        test_results = conditions.map do |key, values_we_want|
           check_one_key(row_hash, key, values_we_want)
        end
        # If all the keys are values_we_want,
        # then add this row to the count.
        test_results.all?
      end
    end

    def check_one_key(row_hash, key, values_we_want)
      if values_we_want.is_a? Array
        values_we_want.include? row_hash[key]
      else
        row_hash[key] == values_we_want
      end
    end


    # Fetches all the asset statistics we need from the database.
    # Fetches 20,000 rows in about a millisecond.
    # We could move much of the counting code above into the SQL and make the DB
    # do more work, but at the cost of some readability; since the fixity report page
    # isn't viewed much (if ever), not worth optimizing this too much.
    def asset_stats
      @asset_stats ||= begin
        checks_are_stale_after = '7 days'
        asset_is_old_after     = '7 days'

        column_hash = {
          # We need the asset's ID to group the records.
          'id': 'kithe_models.id',

          # For debugging:
          'friendlier_id': 'kithe_models.friendlier_id',

          # Does the asset have a file attached to it?
          'stored_file': "file_data ->> 'storage'",

          # How many checks does each asset have?
          'check_count': 'fixity_checks.count',

          # Is this asset due for a check?
          #     Careful, we're using a left join. So here are the possible values:
          #     NULL  means no checks yet.
          #     true  means there are checks, but they're all older than a week.
          #     false means the file was checked at least once in the past week.
          'stale_check': "max(fixity_checks.created_at) < NOW() - INTERVAL '#{checks_are_stale_after}'",

          # Was the asset uploaded "recently" ?
          'recent_asset': "kithe_models.created_at > NOW() - INTERVAL '#{asset_is_old_after}'",
        }

        labels = column_hash.keys
        columns = column_hash.values.
          map { |x| Arel.sql(x) }

        Asset.
          left_outer_joins(:fixity_checks).
          group(:id).pluck(*columns).
          map { |p| labels.zip(p).to_h }
      end
    end
  end
end