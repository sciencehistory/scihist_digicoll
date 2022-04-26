namespace :scihist do
  desc """
    Goes through all the oral histories and generates combined audio derivatives for
    those missing them:

    bundle exec rake scihist:create_full_length_audio_derivatives
  """

  task :create_m4a_combined_audio_derivatives => :environment do
    progress_bar = ProgressBar.create(total: Work.where("json_attributes -> 'genre' ?  'Oral histories'").count, format: "%a %t: |%B| %R/s %c/%u %p%% %e")
    Work.where("json_attributes -> 'genre' ?  'Oral histories'").find_each(batch_size: 10) do |w|
      progress_bar.log("INFO: Starting #{w.title}")
      progress_bar.increment
      if w.oral_history_content!.combined_audio_m4a.present?
        progress_bar.log("INFO: #{w.title} already has m4a format combined audio derivs.")
        next
      end
      CreateCombinedAudioDerivativesJob.perform_now(w)
      progress_bar.log(w.oral_history_content.combined_audio_m4a_data)
      progress_bar.log("INFO: Done with #{w.title}")
    end
  end

end