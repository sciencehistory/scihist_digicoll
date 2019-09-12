require 'scihist_digicoll/assets_needing_fixity_checks'

namespace :scihist_digicoll do
  desc """
  Checks the fixity of some or all Assets in the database.

  To check only a subset today, checking all every 7 days:
    bundle exec rake scihist_digicoll:check_and_prune_fixity

  To run a full check of all assets with stored files:
    CYCLE_LENGTH=0 bundle exec rake scihist_digicoll:check_and_prune_fixity

  To check 1/30th today instea dof 1/7th, checking all every 30 days:
    CYCLE_LENGTH=30 bundle exec rake scihist_digicoll:check_and_prune_fixity

  To run checks, but leave stale checks around without pruning them:
    SKIP_PRUNE='true'  bundle exec rake scihist_digicoll:check_and_prune_fixity

  To just prune stale checks, without checking any assets:
    SKIP_CHECK='true'  bundle exec rake scihist_digicoll:check_and_prune_fixity

  For a progress bar, preface any of these with
    SHOW_PROGRESS_BAR='true'

  """

  task :check_and_prune_fixity => :environment do
    cycle_length = ENV['CYCLE_LENGTH']|| 7

    asset_ids_to_check = ScihistDigicoll::AssetsNeedingFixityChecks.new(cycle_length).asset_ids_to_check

    info = "INFO: checking asset fixity for #{asset_ids_to_check.count} of #{Asset.count} assets"

    if ENV['SHOW_PROGRESS_BAR'] == 'true'
      progress_bar = ProgressBar.create(total: asset_ids_to_check.count, format: "%a %t: |%B| %R/s %c/%u %p%% %e")
      progress_bar.log(info)
    else
      puts info
    end

    asset_ids_to_check.each do | id |
      asset = Asset.find(id)
      if asset.stored?
        checker = FixityChecker.new(asset)
        checker.check        unless ENV['SKIP_CHECK'] == 'true'
        checker.prune_checks unless ENV['SKIP_PRUNE'] == 'true'
      end
      progress_bar.increment unless progress_bar.nil?
    end
  end
end
