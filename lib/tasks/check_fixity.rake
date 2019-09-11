require 'scihist_digicoll/assets_needing_fixity_checks'

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
      ids_to_check = ScihistDigicoll::AssetsNeedingFixityChecks.asset_ids_to_check
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
end
