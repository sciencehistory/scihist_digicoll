namespace :scihist do
  # This code can be removed after we have run it everywhere it needs to be run
  desc "fix OralHistoryContent jsonb data to be hash not serialized string"
  task :fix_oh_file_data => [:environment] do
    OralHistoryContent.find_each do |model|
      if model.combined_audio_mp3_data.kind_of?(String) || model.combined_audio_mp3_data.kind_of?(String)
        puts "Fixing OralHistoryContent #{model.id} for Work #{model.work.friendlier_id}"
        model.combined_audio_mp3_data = JSON.parse(model.combined_audio_mp3_data) if model.combined_audio_mp3_data.kind_of?(String)
        model.combined_audio_webm_data = JSON.parse(model.combined_audio_webm_data) if model.combined_audio_webm_data.kind_of?(String)

        model.save!
      end
    end
  end
end
