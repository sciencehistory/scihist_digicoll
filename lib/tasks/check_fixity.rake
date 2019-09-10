namespace :scihist_digicoll do
  desc """
  Checks the fixity of some or all Assets in the database.

  To check only a subset today, checking all every 7 days:
    bundle exec rake scihist_digicoll:check_fixity

  To check all assets:
    CHECK_ALL_ASSETS_TODAY='true' bundle exec rake scihist_digicoll:check_fixity

  """

  CHECK_CYCLE_LENGTH = 7

  task :check_fixity => :environment do
    asset_count = Asset.all.count
    if asset_count == 0
      abort ("No assets found to check.")
    end

    if ENV['CHECK_ALL_ASSETS_TODAY'] == 'true'
      ids_to_check = Asset.all.pluck(:id)
    else
      # Default recipe:
      # This recipe will:
      #   Check all the assets every CHECK_CYCLE_LENGTH days.
      #   Check roughly the same number of assets every day.
      #   Only load the assets that are about to get checked.
      sieve_integer =  DateTime.now.ajd.to_i
      ids_to_check = sifted_asset_ids(sieve_integer, CHECK_CYCLE_LENGTH)
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

  # Retrieves a convenient subset of asset ids.
  # Allows us to convieniently check only a subset of
  # the assets at a time, but be sure everything eventually
  # gets checked.
  # Pass in 0, and everything will go through the sieve.
  def sifted_asset_ids(sieve_integer, cycle_length)
    ids = Asset.all.pluck(:id).select do |id|
      id.bytes[0..5].sum % cycle_length == sieve_integer % cycle_length
    end
    ids
  end
end
