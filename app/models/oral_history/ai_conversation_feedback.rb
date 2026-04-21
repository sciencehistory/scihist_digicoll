class OralHistory::AiConversationFeedback < ApplicationRecord
  belongs_to :oral_history_ai_conversation, class_name: "OralHistory::AiConversation"
  belongs_to :user
end
