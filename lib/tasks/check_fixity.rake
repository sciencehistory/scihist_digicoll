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
    fixity_check_task_id = rand.to_s[2..4]
    info = "checking asset fixity (task ID #{fixity_check_task_id}) for #{check_lister.expected_num_to_check} of #{Asset.count} assets"
    start_time = Time.now
    count_of_items_checked = 0

    if ENV['SHOW_PROGRESS_BAR'] == 'true'
      progress_bar = ProgressBar.create(total: check_lister.expected_num_to_check, format: "%a %t: |%B| %R/s %c/%u %p%% %e")
      progress_bar.log(info)
    else
      Rails.logger.info(info)
    end

    # let's see if uncached improves our memory consumption?
    ActiveRecord::Base.uncached do
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
        # we're running out of RAM on some fixity check runs on heroku. It may
        # be that `down`, that we use for fetching bytes from S3, just allocates
        # a lot of different Strings, necessarily. Perhaps forcing a periodic
        # GC will help reclaim them?
        GC.start
      end
    end

    end_time = Time.now
    info = "Finished checking asset fixity for #{count_of_items_checked} of #{Asset.count} assets. The task (ID #{fixity_check_task_id} ) took #{end_time - start_time} seconds"


    unless ENV['SHOW_PROGRESS_BAR'] == 'true'
      Rails.logger.info(info)
    end
  end

  namespace :check_fixity do
    desc "find any assets marked as overdue for fixity check, and check them"
    task :complete_overdue => :environment do

      stored_file  = FixityReport::STORED_FILE_SQL
      recent_asset = FixityReport::RECENT_ASSET_SQL
      stale_check  = FixityReport::STALE_CHECKS_SQL
      count_of_items_checked = 0;

      overdue_assets = Asset.where(id: Asset.
        select("kithe_models.id").
        left_outer_joins(:fixity_checks).group(:id).having(stored_file).
        having("#{recent_asset} = false").
        having("(#{stale_check}) OR (#{stale_check} is NULL)"))

      overdue_assets.find_each do |asset|
        if asset.stored?
          checker = FixityChecker.new(asset)
          new_check = checker.check
          FixityCheckFailureService.new(new_check).send if new_check&.failed?
          count_of_items_checked = count_of_items_checked + 1
        end
      end

      if count_of_items_checked > 0
        puts "complete_stale_checks: found and checked #{count_of_items_checked} stale assets!"
      end
    end
  end
end
