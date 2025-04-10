class AddOralHistoryTranscriptSequenceFiles < ActiveRecord::Migration[8.0]
  def change
    add_column :oral_history_content, :input_docx_transcript_data, :jsonb
    add_column :oral_history_content, :output_sequenced_docx_transcript_data, :jsonb
  end
end
