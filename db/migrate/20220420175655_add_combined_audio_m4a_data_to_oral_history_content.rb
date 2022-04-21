class AddCombinedAudioM4aDataToOralHistoryContent < ActiveRecord::Migration[6.1]
  def change
    add_column :oral_history_content, :combined_audio_m4a_data, :jsonb
  end
end
