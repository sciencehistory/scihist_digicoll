namespace :scihist do
  namespace :data_fixes do

    desc """
      Add exiftool results to Asset#exiftool_result
    """
    task :add_exiftool_result => :environment do
      scope = Asset.where("derived_metadata_jsonb ->> 'exiftool_result' is null")

      progress_bar = ProgressBar.create(total: scope.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      scope.find_each do |asset|
        asset.store_exiftool
        asset.save!

        progress_bar.increment
      rescue Shrine::FileNotFound => e
        # meh, we dont' worry about the file not existing, skip it.
      end
    end
  end
end
