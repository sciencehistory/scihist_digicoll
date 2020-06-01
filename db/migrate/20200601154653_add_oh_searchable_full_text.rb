class AddOhSearchableFullText < ActiveRecord::Migration[6.0]
  def change
    add_column :oral_history_content, :searchable_plain_text_transcript, :text
  end
end
