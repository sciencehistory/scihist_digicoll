# Try to be idempotent!
class OralHistoryAiConversationJob < ApplicationJob
  def self.launch(question:, session_id:)
    conversation = OralHistory::AiConversation.create!(question: question, session_id: session_id)
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
    unless ai_conversation.queued? || ai_conversation.error?
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
