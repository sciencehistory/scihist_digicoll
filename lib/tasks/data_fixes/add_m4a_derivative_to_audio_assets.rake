namespace :scihist do
  namespace :data_fixes do
    desc """
      Enqueues a job for the creation of an m4a derivative -- lazily -- for all flac audio assets.
      bundle exec rake scihist:data_fixes:add_m4a_derivative_to_audio_assets
    """

    task :add_m4a_derivative_to_audio_assets => :environment do
      scope = Asset.where("(file_data -> 'metadata' ->> 'mime_type' like 'audio/flac') or (file_data -> 'metadata' ->> 'mime_type' like 'audio/x-flac')")
      progress_bar = ProgressBar.create(total: scope.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)
      queue = :special_jobs
      scope.find_each do |audio_asset|     
        if :m4a.in? audio_asset.file_derivatives.keys
          progress_bar.log("SKIPPING: Already found m4a for #{audio_asset.friendlier_id}")
          progress_bar.increment
          next
        end
        progress_bar.log("Enqueuing #{audio_asset.friendlier_id}")
        CreateM4aDerivativeJob.set(queue: queue).perform_later(audio_asset)
        progress_bar.increment
      end
    end
  end
end
