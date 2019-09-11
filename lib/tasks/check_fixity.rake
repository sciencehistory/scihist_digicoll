require 'scihist_digicoll/assets_needing_fixity_checks'

namespace :scihist_digicoll do
  desc """
  Checks the fixity of some or all Assets in the database.

  To check only a subset today, checking all every 7 days:
    bundle exec rake scihist_digicoll:check_and_prune_fixity

  To run a full check of all assets with stored files:
    CHECK_ALL_ASSETS_TODAY='true' bundle exec rake scihist_digicoll:check_and_prune_fixity

  To run checks, but leave stale checks around without pruning them:
    SKIP_PRUNE='true'  bundle exec rake scihist_digicoll:check_and_prune_fixity

  To just prune stale checks, without checking any assets:
    SKIP_CHECK='true'  bundle exec rake scihist_digicoll:check_and_prune_fixity

  """

  task :check_and_prune_fixity => :environment do
    cycle_length = ENV['CHECK_ALL_ASSETS_TODAY'] == 'true' ? 0 : 7
    ScihistDigicoll::AssetsNeedingFixityChecks.
      assets_to_check(cycle_length) do | asset |
      if asset.stored?
        checker = FixityChecker.new(asset)
        checker.check        unless ENV['SKIP_CHECK'] == 'true'
        checker.prune_checks unless ENV['SKIP_PRUNE'] == 'true'
      end
    end
  end
end
