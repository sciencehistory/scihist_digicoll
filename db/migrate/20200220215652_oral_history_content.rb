class OralHistoryContent < ActiveRecord::Migration[5.2]
  def change
    create_table :oral_history_content do |t|
      t.uuid :work_id, null: false, index: { unique: true }

      t.jsonb :combined_audio_mp3_data
      t.jsonb :combined_audio_webm_data
      t.string :combined_audio_fingerprint
      t.jsonb :combined_audio_component_metadata

      t.text :ohms_xml

      t.timestamps
    end
    add_foreign_key :oral_history_content, :kithe_models, column: :work_id
  end
end
