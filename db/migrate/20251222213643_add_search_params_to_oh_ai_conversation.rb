class AddSearchParamsToOhAiConversation < ActiveRecord::Migration[8.0]
  def change
    add_column :oral_history_ai_conversations, :search_params, :jsonb
  end
end
