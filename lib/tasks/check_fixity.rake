namespace :scihist do
  desc """
  Checks the fixity of some or all Assets in the database.

  To check only a subset today, checking all every 7 days:
    bundle exec rake scihist:check_fixity

  To run a full check of all assets with stored files:
    CYCLE_LENGTH=0 bundle exec rake scihist:check_fixity

  To check 1/30th today instea dof 1/7th, checking all every 30 days:
    CYCLE_LENGTH=30 bundle exec rake scihist:check_fixity

  To run checks, but leave stale checks around without pruning them:
    SKIP_PRUNE='true'  bundle exec rake scihist:check_fixity

  To just prune stale checks, without checking any assets:
    SKIP_CHECK='true'  bundle exec rake scihist:check_fixity

  For a progress bar, preface any of these with
    SHOW_PROGRESS_BAR='true'

  """

  task :check_fixity => :environment do
    cycle_length = ENV['CYCLE_LENGTH'].nil? ? ScihistDigicoll::AssetsNeedingFixityChecks::DEFAULT_PERIOD_IN_DAYS : Integer(ENV['CYCLE_LENGTH'])
    check_lister = ScihistDigicoll::AssetsNeedingFixityChecks.new(cycle_length)
    info = "checking asset fixity (task ID #{fixity_check_task_id}) for #{check_lister.expected_num_to_check} of #{Asset.count} assets"
    fixity_check_task_id = rand.to_s[2..4]
    start_time = Time.now
    count_of_items_checked = 0

    if ENV['SHOW_PROGRESS_BAR'] == 'true'
      progress_bar = ProgressBar.create(total: check_lister.expected_num_to_check, format: "%a %t: |%B| %R/s %c/%u %p%% %e")
      progress_bar.log(info)
    else
      Rails.logger.info(info)
    end

    # Use transaction for every 10 FixityChecks to add, should speed things up.
    check_lister.assets_to_check.each_slice(10) do | transaction_batch |
      Asset.transaction do
        transaction_batch.each do |asset|
          if asset.stored?
            checker = FixityChecker.new(asset)
            new_check = checker.check  unless ENV['SKIP_CHECK'] == 'true'
            checker.prune_checks       unless ENV['SKIP_PRUNE'] == 'true'
            FixityCheckFailureService.new(new_check).send if new_check&.failed?
            count_of_items_checked = count_of_items_checked + 1 unless ENV['SKIP_CHECK'] == 'true'
          end
          progress_bar.increment unless progress_bar.nil?
        end
      end
    end

    end_time = Time.now
    info = "Finished checking asset fixity for #{check_lister.count_of_items_checked} of #{Asset.count} assets. The task (ID #{fixity_check_task_id} ) took #{end_time - start_time} seconds"


    unless ENV['SHOW_PROGRESS_BAR'] == 'true'
      Rails.logger.info(info)
    end


  end
end
