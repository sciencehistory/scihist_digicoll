namespace :scihist_digicoll do
  desc """
  Checks the fixity of all Assets in the database.
  """
  task :check_fixity => :environment do
    asset_count = Asset.all.count
    if asset_count == 0
      abort ("No assets found to check.")
    end
    progress_bar = ProgressBar.create(total: asset_count, format: "%a %t: |%B| %R/s %c/%u %p%% %e")
    progress_bar.log("INFO: checking asset fixity")
    Asset.all.each do |asset|
      FixityCheckLog.check(asset)
      progress_bar.increment
    end
  end
end
