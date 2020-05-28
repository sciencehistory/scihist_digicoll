class AddCreationJobStatusToOralHistoryContent < ActiveRecord::Migration[6.0]
  def change
    add_column :oral_history_content, :combined_audio_derivatives_creation_status, :string
    add_column :oral_history_content, :combined_audio_derivatives_creation_status_changed_at, :datetime
  end
end
