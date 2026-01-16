class AddTimingsToAiConversation < ActiveRecord::Migration[8.0]
  def change
    add_column :oral_history_ai_conversations, :timings, :jsonb, default: []
  end
end
