namespace :scihist do
  namespace :oral_history do
    desc """
      Goes through all the oral histories, and enqueues EnsureCombinedAudioDerivativeJob for any
      whose combined audio derivative is missing, stale, in the wrong storage location, or should
      be deleted because there is no available audio. Suitable for running nightly.

      This does NOT actually do the processing. Jobs go to the default queue; for a large backfill,
      QUEUE=special_jobs sends them to special_worker dynos (see Procfile).

      INTERACTIVE=false will hide progress bar and other interactive status

      RECREATE=true deletes and re-creates every combined audio derivative, even if already good.

      bundle exec rake scihist:oral_history:ensure_combined_audio_derivatives
    """
    task :ensure_combined_audio_derivatives => :environment do
      job = ENV['QUEUE'].present? ? EnsureCombinedAudioDerivativeJob.set(queue: ENV['QUEUE']) : EnsureCombinedAudioDerivativeJob
      interactive = ENV['INTERACTIVE'] != "false"
      recreate = ENV['RECREATE'] == "true"
      checked = enqueued = 0

      scope = Work.jsonb_contains(genre: 'Oral histories')

      if interactive
        progress_bar = ProgressBar.create(total: scope.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT, output: $stderr)
      end

      scope.includes(:oral_history_content).strict_loading.find_each(batch_size: 10) do |w|
        progress_bar.increment if interactive
        checked += 1

        # recreate everything, no checks needed
        unless recreate
          # unsaved if missing, so we don't create sidecars as a side effect
          oral_history_content = w.oral_history_content || OralHistoryContent.new(work: w)

          correct_location = oral_history_content.combined_audio_in_correct_storage?
          correct_file     = oral_history_content.combined_audio_up_to_date?
          present_file     = !oral_history_content.combined_audio_m4a.nil?

          next if correct_file && correct_location # we're good

          # nothing to create, nothing to delete
          next if !present_file && !CombinedAudioDerivativeCreator.new(w).available_members?

          if !correct_location
            reason = "wrong storage location (currently #{oral_history_content.combined_audio_m4a.storage_key}, should be #{oral_history_content.combined_audio_store_key})"
          elsif !correct_file && !present_file
            reason = "missing file"
          else
            reason = "bad file (fingerprint mismatch)"
          end

          Rails.logger.warn("scihist:oral_history:ensure_combined_audio_derivatives: enqueuing EnsureCombinedAudioDerivativeJob for #{w.friendlier_id}: #{reason}")
        end

        job.perform_later(w, force: recreate)
        enqueued += 1
      end

      summary = "scihist:oral_history:ensure_combined_audio_derivatives: checked #{checked} oral histories, enqueued #{enqueued} jobs to create combined derivative"
      Rails.logger.warn(summary)
      progress_bar.log(summary) if interactive
    end
  end
end
