class RenameSearchableTranscriptSource < ActiveRecord::Migration[6.0]
  def change
    rename_column :oral_history_content, :searchable_plain_text_transcript, :searchable_transcript_source
  end
end
