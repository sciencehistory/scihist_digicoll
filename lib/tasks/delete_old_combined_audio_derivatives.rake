namespace :scihist do
  desc """
    Goes through all the oral histories and generates combined audio derivatives for
    those missing them:

    bundle exec rake scihist:delete_old_combined_audio_derivatives
  """

  task :delete_old_combined_audio_derivatives => :environment do
    progress_bar = ProgressBar.create(total: Work.where("json_attributes -> 'genre' ?  'Oral histories'").count, format: "%a %t: |%B| %R/s %c/%u %p%% %e")
    Work.where("json_attributes -> 'genre' ?  'Oral histories'").find_each(batch_size: 10) do |w|
      oh = w.oral_history_content!

      unless oh.combined_audio_m4a.present?
        progress_bar.log("INFO: Skipping #{w.title}: new derivs not ready.")
        next
      end
      
      oh&.combined_audio_mp3&.delete
      oh&.combined_audio_mp3      = nil
      oh&.combined_audio_mp3_data = nil
      oh&.combined_audio_webm&.delete
      oh&.combined_audio_webm      = nil
      oh&.combined_audio_webm_data = nil
    
      oh.save!
      progress_bar.log("INFO: Deleted old derivs for #{w.title}")
      progress_bar.increment
    end
  end

end