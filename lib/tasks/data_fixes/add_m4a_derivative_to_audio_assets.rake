namespace :scihist do
  namespace :data_fixes do
    desc """
      Creates an m4a derivative -- lazily -- for all flac audio assets.
      bundle exec rake scihist:data_fixes:add_m4a_derivative_to_audio_assets
    """

    task :add_m4a_derivative_to_audio_assets => :environment do
      scope = Asset.where("file_data -> 'metadata' ->> 'mime_type' like 'audio/%'")

      progress_bar = ProgressBar.create(total: scope.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      scope.find_each do |audio_asset|
        unless audio_asset.stored? && audio_asset.content_type.end_with?('flac')
          begin
            progress_bar.title = audio_asset.friendlier_id
            audio_asset.create_derivatives(lazy: true)
          rescue Shrine::FileNotFound => e
            progress_bar.log("original missing for #{audio_asset.friendlier_id}")
          end
        end
        progress_bar.increment
      end
    end
  end
end
