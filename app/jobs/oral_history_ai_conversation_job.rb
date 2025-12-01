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

    # Get and save embedding if it's not already there (it costs money, so we want to cache it!),
    # and set status to in_process
    ai_conversation.question_embedding ||= OralHistoryChunk.get_openai_embedding(ai_conversation.question)
    ai_conversation.status = :in_process
    ai_conversation.save!

    # Start the conversation, could take 10-20 seconds even.
    interactor = OralHistory::ClaudeInteractor.new(question: ai_conversation.question, question_embedding: ai_conversation.question_embedding)
    response = interactor.get_response(conversation_record: ai_conversation)

    ai_conversation.answer_json = interactor.extract_answer(response)
    ai_conversation.status = :success
    ai_conversation.save!

  rescue Aws::Errors::ServiceError, OralHistory::ClaudeInteractor::OutputFormattingError => e
    ai_conversation.status = :error
    ai_conversation.error_info = {
      "exception_class" => e.class.name,
      "message" => e.message,
      "backtrace" => Rails.backtrace_cleaner.clean(e.backtrace).collect(&:to_json)
    }
    ai_conversation.save!
  end
end
