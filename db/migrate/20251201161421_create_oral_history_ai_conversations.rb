class CreateOralHistoryAiConversations < ActiveRecord::Migration[8.0]
  def change
    create_table :oral_history_ai_conversations do |t|
      t.string :status, null: false, default: "queued"
      t.uuid :external_id, default: "gen_random_uuid()", null: false
      t.string :session_id
      t.string :question, null: false
      t.vector :question_embedding, limit: 3072
      t.jsonb :response_metadata, default: {}
      t.jsonb :chunks_used, default: {}
      t.jsonb :error_info
      t.jsonb :answer_json
      t.datetime :request_sent_at

      t.timestamps
    end
  end
end
