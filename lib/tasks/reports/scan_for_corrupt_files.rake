namespace :scihist do
  namespace :reports do
    desc """Scan for missing metadata, missing files, incomplete characterization, and corrupt files.

      bundle exec rake scihist:reports:scan_for_absent_files_or_metadata
      bundle exec rake scihist:reports:scan_for_corrupt_files

      See also:
        bundle exec rake scihist:data_fixes:add_audio_characterization
        bundle exec rake scihist:data_fixes:add_exiftool_result


    """
    task :scan_for_absent_files_or_metadata => :environment do
      progress_bar = ProgressBar.create(total: Asset.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)
      Kithe::Indexable.index_with(batching: true) do
        Asset.find_each(batch_size: 10) do |a|
          if !a.stored?
            pp "#{a.friendlier_id }: Not stored"
          elsif a.content_type == "application/octet-stream" || a.content_type.empty?
            pp "#{a.friendlier_id }: No content type"
          end
          
          if a.content_type&.start_with?("audio/") && a.file_metadata["bitrate"].blank?
            pp "#{a.friendlier_id }: No bitrate."
          elsif a.content_type == "image/tiff" && a.exiftool_result.blank?
            pp "#{a.friendlier_id }: No exiftool_result."
          end
          
          progress_bar.increment
        end
      end
    end

    task :scan_for_corrupt_files => :environment do
      progress_bar = ProgressBar.create(total: Asset.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)
      Kithe::Indexable.index_with(batching: true) do
        Asset.find_each(batch_size: 10) do |a|
          begin
            a.invalidate_audio_missing_metadata if a.content_type&.start_with?("audio/")
            a.invalidate_corrupt_tiff if a.content_type == "image/tiff"
          rescue UncaughtThrowError => e
            pp "#{a.friendlier_id }: #{a.reload.promotion_validation_errors}"
          end
          progress_bar.increment
        end
      end
    end
  end
end
