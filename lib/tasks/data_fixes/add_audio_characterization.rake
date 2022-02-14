namespace :scihist do
  namespace :data_fixes do

    desc """
      Add characterization metadata to audio files that do not have it yet
    """
    task :add_audio_characterization => :environment do
      scope = Asset.where("file_data -> 'metadata' ->> 'mime_type' like 'audio/%'")

      progress_bar = ProgressBar.create(total: scope.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      scope.find_each do |audio_asset|
        next unless audio_asset.stored?

        # if it already seems to have metadata...
        next if audio_asset.file_metadata["bitrate"].present?

        input = if audio_asset.file.url.present? && audio_asset.file.url.start_with?("http")
          audio_asset.file.url
        else
          audio_asset.file.download
        end

        audio_asset.file.metadata.merge!(
          Kithe::FfprobeCharacterization.new(input).normalized_metadata
        )
        audio_asset.save!

        progress_bar.increment

        input.unlink if input.respond_to?(:unlink) # TempFile
      end
    end
  end
end
