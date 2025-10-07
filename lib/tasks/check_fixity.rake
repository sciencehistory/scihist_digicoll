namespace :scihist do
  desc """
  Checks the fixity of some or all Assets in the database.

  To check only a subset today, checking all every 7 days:
    bundle exec rake scihist:check_fixity

  To run a full check of all assets with stored files:
    CYCLE_LENGTH=0 bundle exec rake scihist:check_fixity

  To check 1/30th today instea dof 1/7th, checking all every 30 days:
    CYCLE_LENGTH=30 bundle exec rake scihist:check_fixity

  For a progress bar, preface any of these with
    SHOW_PROGRESS_BAR='true'

  """

  task :check_fixity => :environment do
    cycle_length = ENV['CYCLE_LENGTH'].nil? ? ScihistDigicoll::AssetsNeedingFixityChecks::DEFAULT_PERIOD_IN_DAYS : Integer(ENV['CYCLE_LENGTH'])
    check_lister = ScihistDigicoll::AssetsNeedingFixityChecks.new(cycle_length)
    Rails.logger.info "check_fixity: starting fixity check for #{check_lister.expected_num_to_check} of #{Asset.count} assets."

    if ENV['SHOW_PROGRESS_BAR'] == 'true'
      progress_bar = ProgressBar.create(total: check_lister.expected_num_to_check, format: "%a %t: |%B| %R/s %c/%u %p%% %e")
    end

    count_of_items_checked = 0

    # let's see if uncached improves our memory consumption?
    ActiveRecord::Base.uncached do
      # Use transaction for every 10 FixityChecks to add, should speed things up.
      check_lister.assets_to_check.each_slice(10) do | transaction_batch |
        Asset.transaction do
          transaction_batch.each do |asset|
            FixityChecker.new(asset).check_prune_report
            count_of_items_checked = count_of_items_checked + 1
            progress_bar.increment if progress_bar
          end
        end
        # we're running out of RAM on some fixity check runs on heroku. It may
        # be that `down`, that we use for fetching bytes from S3, just allocates
        # a lot of different Strings, necessarily. Perhaps forcing a periodic
        # GC will help reclaim them?
        GC.start
      end
    end

    if count_of_items_checked > 0
      Rails.logger.info "check_fixity: found and checked #{count_of_items_checked} assets."
    end
  end

  namespace :check_fixity do
    desc "find any assets marked as overdue for fixity check, and check them"
    task :complete_overdue => :environment do
      reporter = FixityReport.new
      # default no progress bar for scheduled job, but optionally can add it...
      if ENV['SHOW_PROGRESS_BAR'] == 'true'
        progress_bar =  ProgressBar.create(total: reporter.not_recent_with_no_checks_or_stale_checks, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)
      end
      count_of_items_checked = 0;
      reporter.need_checks_assets_relation.find_each do |asset|
        FixityChecker.new(asset).check_prune_report
        count_of_items_checked = count_of_items_checked + 1
        progress_bar.increment if progress_bar
      end
      if count_of_items_checked > 0
        Rails.logger.info "complete_stale_checks: found and checked #{count_of_items_checked} stale assets."
      end
    end
  end
end
