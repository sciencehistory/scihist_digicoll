namespace :scihist do
  namespace :reports do
    desc """Scan for missing metadata, missing files, incomplete characterization, and corrupt files.
    These two tasks are meant to be run in sequence:
      bundle exec rake scihist:reports:scan_for_absent_files_or_metadata scihist:reports:scan_for_corrupt_files

    """
    task :scan_for_absent_files_or_metadata => :environment do
      desc """  Sanity check that all assets have:
          stored files
          a content type
          appropriate characterization info stored.
        """
      progress_bar = ProgressBar.create(total: Asset.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)
      Kithe::Indexable.index_with(batching: true) do
        Asset.find_each(batch_size: 10) do |a|
          # Files should be stored and have a content type:
          if !a.stored?
            progress_bar.log "#{a.friendlier_id }: Not stored"
          elsif a.content_type == "application/octet-stream" || a.content_type.empty?
            progress_bar.log "#{a.friendlier_id }: No content type"
          end

          # Files should be properly characterized:
          if a.content_type&.start_with?("audio/") && a.file_metadata["bitrate"].blank?
            progress_bar.log "#{a.friendlier_id }: No bitrate."
          elsif a.content_type == "image/tiff" && a.exiftool_result.blank?
            progress_bar.log "#{a.friendlier_id }: No exiftool_result."
          end
          progress_bar.increment
        end
      end
      puts "All assets have been checked for characterization metadata."
    end

    task :scan_for_corrupt_files => :environment do
      desc """
        Run image and sound validation code on all assets.
        Catch :abort and display any validation errors.
      """
      progress_bar = ProgressBar.create(total: Asset.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)
      Kithe::Indexable.index_with(batching: true) do
        Asset.find_each(batch_size: 10) do |a|
          begin
            # Run validation code, just as if the asset had just been ingested:
            a.invalidate_audio_missing_metadata if a.content_type.start_with? "audio/"
            a.invalidate_corrupt_tiff           if a.content_type == "image/tiff"            
          
          # The above methods throw :abort if the file doesn't pass characterization.
          # Catch it, and show the validation errors.
          rescue UncaughtThrowError => e
            progress_bar.log "#{a.friendlier_id }: #{a.reload.promotion_validation_errors}"
          end
          progress_bar.increment
        end
      end
      puts "All assets have been checked for corrupt files."
    end
  end
end
