namespace :scihist do
  desc """
  A simple version of fixity check.
  """

  task :check_fixity_simple => :environment do
    fixity_check_task_id = rand.to_s[2..4]
    count_of_items_checked = 0

    selected_assets_scope = Asset.
      select("kithe_models.id").
      left_outer_joins(:fixity_checks).
      group(:id).
      order(Arel.sql "max(fixity_checks.created_at) nulls first").
      limit(10)

    assets_to_check = Asset.where(id: selected_assets_scope)

    if ENV['SHOW_PROGRESS_BAR'] == 'true'
      progress_bar = ProgressBar.create(total: assets_to_check.count, format: "%a %t: |%B| %R/s %c/%u %p%% %e")
    end

    assets_to_check.each do |asset|
      if asset.stored?
        checker = FixityChecker.new(asset)
        new_check = checker.check
        checker.prune_checks
        FixityCheckFailureService.new(new_check).send if new_check&.failed?
        count_of_items_checked = count_of_items_checked + 1
        Rails.logger.info("FIXITY Check process #{fixity_check_task_id} number #{count_of_items_checked} for asset #{asset.friendlier_id}")
      end
      progress_bar.increment unless progress_bar.nil?
    end
    Rails.logger.info("FIXITY Check process #{fixity_check_task_id} completed.")
  end
end

