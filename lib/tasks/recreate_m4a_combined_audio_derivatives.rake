namespace :scihist do
  desc """
    Goes through all the oral histories. Where needed, adds a perform_later
    job to :special_jobs to create m4a audio derivatives for them.

    This does NOT actually do the processing.

    bundle exec rake scihist:create_m4a_combined_audio_derivatives
  """

  task :create_m4a_combined_audio_derivatives => :environment do

    progress_bar = ProgressBar.create(total: Work.where("json_attributes -> 'genre' ?  'Oral histories'").count, format: "%a %t: |%B| %R/s %c/%u %p%% %e")

    # Add these jobs to the special_jobs queue
    # where they can be picked up (only) by special_worker dynos
    #
    # See  config/resque-pool-special-worker.yml .
    queue = :special_jobs

    Work.where("json_attributes -> 'genre' ?  'Oral histories'").find_each(batch_size: 10) do |w|
      progress_bar.log("INFO: START #{w.title}")
      progress_bar.increment

      cutoff_date = Time.now() - 10.day

      has_recent_combined_audio = (
        w&.oral_history_content&.combined_audio_derivatives_job_status_changed_at.present? &&
        w.oral_history_content.combined_audio_derivatives_job_status_changed_at > cutoff_date
      )

      if has_recent_combined_audio
          progress_bar.log("INFO: SKIP #{w.title}. Already has recent combined audio.")
        next
      end
      progress_bar.log "INFO: Found an old one! #{w.oral_history_content.combined_audio_derivatives_job_status_changed_at} is before #{(Time.now() - 3.day)}."

      # Let's not enqueue the job unless there are published audio assets to re-encode.
      # This step will be executed twice for jobs that *are* added to the queue,
      # but it makes even less sense to muddy the queue with hundreds of trivial
      # jobs that will only take a fraction of a second to execute.
      unless CombinedAudioDerivativeCreator.new(w).available_members?
        progress_bar.log "INFO: SKIP #{w.title}. No published audio segments."
        next
      end
      progress_bar.log "INFO: Adding #{}{w.title} to queue!"
      # CreateCombinedAudioDerivativesJob.set(queue: queue).perform_later(w)
    end
  end

end