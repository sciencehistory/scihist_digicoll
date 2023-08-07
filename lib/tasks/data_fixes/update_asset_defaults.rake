namespace :scihist do
  namespace :data_fixes do

    desc """
      Save Assets that have changed defaults on load
    """
    task :update_assets_with_defaults => :environment do
      progress_bar = ProgressBar.create(total: Asset.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      Asset.find_each do |asset|
        # If right after load the Asset has changed, that can happen due to changed embedded
        # json defaults, let's just save it again to get those in DB.
        if asset.changed?
          asset.save!
        end

        progress_bar.increment
      end
    end
  end
end
