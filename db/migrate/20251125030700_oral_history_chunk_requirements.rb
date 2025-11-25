class OralHistoryChunkRequirements < ActiveRecord::Migration[8.0]
  def change
    change_column_null :oral_history_chunks, :start_paragraph_number, false
    change_column_null :oral_history_chunks, :end_paragraph_number, false
    change_column_null :oral_history_chunks, :text, false
  end
end
