# Try to be idempotent!
class OralHistoryAiConversationJob < ApplicationJob
  def self.launch(question:, session_id:, search_params: {})
    conversation = OralHistory::AiConversation.create!(question: question.strip, session_id: session_id, search_params: search_params)
    self.perform_later(conversation)

    return conversation
  end

  def perform(ai_conversation)
    unless ai_conversation.kind_of?(OralHistory::AiConversation)
      raise ArgumentError("must be an OralHistory::AiConversation not #{ai_conversation.class}")
    end

    # Error we can re-run, otherwise it's not in runnable state.
    # TODO: if it's stuck after some timeout, we might be willing to re-start?
    # Or that might not be the right flow.
    unless ai_conversation.status_queued? || ai_conversation.status_error?
      Rails.info.log("#{self.class.name}: #{ai_conversation.class.name} #{ai_conversation.id}: Can't exec conversation in status #{ai_conversation.status}")
      return
    end

    ai_conversation.exec_and_record_interaction
  rescue StandardError => e
    # most errors should have been caught inside exec_and_record_interaction, but just in case
    ai_conversation.record_error_state(e)
    raise e
  end
end
