namespace :scihist do
  namespace :data_fixes do

    desc """
      Extract selected exiftool as normalized metadata, via `special_job` bg jobs

      Or in foreground with FOREGROUND=true
    """
    task :extract_normalized_exiftool => :environment do
      scope = Asset.where("derived_metadata_jsonb ->> 'exiftool_result' is not null")

      progress_bar = ProgressBar.create(total: scope.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      scope.find_in_batches(batch_size: 100) do |batch|
        Asset.transaction do
          Kithe::Indexable.index_with(batching: true) do
            batch.each do |asset|
              asset.set_selected_normalized_exiftool
              asset.save!
              progress_bar.increment
            rescue Shrine::FileNotFound => e
              # meh, we dont' worry about the file not existing, skip it.
            end
          end
        end
      end
    end
  end
end
