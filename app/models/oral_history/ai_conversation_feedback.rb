class OralHistory::AiConversationFeedback < ApplicationRecord
  self.table_name = "oral_history_ai_conversation_feedbacks"

  belongs_to :ai_conversation,
    class_name: "OralHistory::AiConversation",
    foreign_key: :oral_history_ai_conversation_id

  belongs_to :user
end
