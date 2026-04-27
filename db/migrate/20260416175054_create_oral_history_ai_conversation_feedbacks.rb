class CreateOralHistoryAiConversationFeedbacks < ActiveRecord::Migration[8.1]
  def change
    create_table :oral_history_ai_conversation_feedbacks do |t|
      t.integer :rating
      t.text :comment
      t.references :oral_history_ai_conversation, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
