class RemoveCombinedAudioMp3DataFromOralHistoryContent < ActiveRecord::Migration[6.1]
  def change
    remove_column :oral_history_content, :combined_audio_mp3_data,  :jsonb
    remove_column :oral_history_content, :combined_audio_webm_data, :jsonb
  end
end
