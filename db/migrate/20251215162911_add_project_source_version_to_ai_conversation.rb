class AddProjectSourceVersionToAiConversation < ActiveRecord::Migration[8.0]
  def change
    add_column :oral_history_ai_conversations, :project_source_version, :string
  end
end
