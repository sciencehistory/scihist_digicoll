namespace :scihist do
  desc """
    Goes through all the oral histories and generates combined audio derivatives for
    those missing them:

    bundle exec rake scihist:create_full_length_audio_derivatives
  """

  task :create_full_length_audio_derivatives => :environment do
    progress_bar = ProgressBar.create(total: Work.where("json_attributes -> 'genre' ?  'Oral histories'").count, format: "%a %t: |%B| %R/s %c/%u %p%% %e")
    Work.where("json_attributes -> 'genre' ?  'Oral histories'").find_each(batch_size: 10) do |w|
      progress_bar.log("INFO: Starting #{w.title}")
      if w.oral_history_content!.combined_audio_good?
        progress_bar.log("INFO: #{w.title} is already up to date.")
        progress_bar.increment
        next
      end
      EnsureCombinedAudioDerivativeJob.perform_now(w)
      progress_bar.log("INFO: Done with #{w.title}")
      progress_bar.increment
    end
  end

end