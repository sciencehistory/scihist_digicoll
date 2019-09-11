namespace :scihist_digicoll do
  desc """
  Checks the fixity of some or all Assets in the database.

  To check only a subset today, checking all every 7 days:
    bundle exec rake scihist_digicoll:check_fixity

  To check all assets:
    CHECK_ALL_ASSETS_TODAY='true' bundle exec rake scihist_digicoll:check_fixity

  """


  task :check_fixity => :environment do
    asset_count = Asset.all.count
    if asset_count == 0
      abort ("No assets found to check.")
    end

    if ENV['CHECK_ALL_ASSETS_TODAY'] == 'true'
      ids_to_check = Asset.all.pluck(:id)
    else
      # This recipe will:
      #   Check all the assets every few days.
      #   Check exactly the same number of assets every day.
      #   Only load the assets that are about to get checked.
      ids_to_check = sifted_asset_ids
    end

    progress_bar = ProgressBar.create(total: ids_to_check.count, format: "%a %t: |%B| %R/s %c/%u %p%% %e")
    progress_bar.log("INFO: checking asset fixity for #{ids_to_check.count} of #{Asset.count} assets")

    ids_to_check.each do |id|
      asset = Asset.find(id)
      if asset.stored?
        checker = FixityChecker.new(asset)
        checker.check
        checker.prune_checks
      end
      progress_bar.increment
    end
  end

  # OLD METHOD
  # Retrieves a convenient subset of asset ids.
  # Allows us to convieniently check only a subset of
  # the assets at a time, but be sure everything eventually
  # gets checked.
  # Pass in 0, and everything will go through the sieve.

  #CHECK_CYCLE_LENGTH = 7

  def old_sifted_asset_ids(sieve_integer, cycle_length)
    ids = Asset.all.pluck(:id).select do |id|
      id.bytes[0..5].sum % cycle_length == sieve_integer % cycle_length
    end
    ids
  end

  # Returns the ids for the assets that need to be checked the most.
  # Assets with NO CHECK on record at all are picked first.
  # Then come assets whose MOST RECENT CHECK is the OLDEST.
  # We pick 5000 at a time, which ensures (as of 2019)
  # that all assets get checked at least once a week or so.
  def sifted_asset_ids
    sql = """
      SELECT kithe_models.id
      FROM kithe_models
      LEFT JOIN fixity_checks
      ON kithe_models.id = fixity_checks.asset_id
      WHERE kithe_models.type = 'Asset'
      GROUP BY kithe_models.id
      ORDER BY max(fixity_checks.created_at) nulls first
      LIMIT 5000;
    """
    ActiveRecord::Base.connection.exec_query(sql).rows.map { |r| r.first }
  end
end
