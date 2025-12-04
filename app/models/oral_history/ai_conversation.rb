# Represents an interaction with Claude AI with an oral history question
#
# We need to store state for background job. We may also use it to evaluate/review/analyze
# question lots.
#
# For now we have one question, one answer, we don't preserve context for longer conversation
#  -- if we were to move to multi-turn conversations, we may have to refactor db schema.
#
# #external_id is a uuid we can use for a URL
#
# We want to record chunks used with their cosine distance as fetched -- for now we just
# stuff it in json cause it's convenient, we could make an actual normalized join table
# in the future. not even attr_json
class OralHistory::AiConversation < ApplicationRecord
  self.table_name = "oral_history_ai_conversations"

  self.filter_attributes += [:question_embedding] # it's just too long

  enum :status, { queued: "queued", in_process: "in_process", success: "success", error: "error" }, prefix: :status

  # Actually talk to Claude based on question preserved here, and record answer and metadata as
  # we go. This could take 10+ seconds, so is usually done in a background job.
  #
  # This will do possibly multiple save!s of self to save state.
  def exec_and_record_interaction
    # if it's done or has an in_process, then refuse to do it again. But we can retry an error.
    unless status_queued? || status_error?
      raise RuntimeError.new("can't exec_and_record_interaction on status #{status}")
    end

    # Get and save embedding if it's not already there (it costs money, so we want to cache it!),
    # and set status to in_process
    self.question_embedding ||= OralHistoryChunk.get_openai_embedding(self.question)
    self.status = :in_process
    self.error_info = nil # in case it was error state before
    self.save!

    # Start the conversation, could take 10-20 seconds even.
    interactor = OralHistory::ClaudeInteractor.new(question: self.question, question_embedding: self.question_embedding)
    response = interactor.get_response(conversation_record: self)

    self.answer_json = interactor.extract_answer(response)
    self.status = :success
    self.save!

  rescue Aws::Errors::ServiceError, OralHistory::ClaudeInteractor::OutputFormattingError => e
    record_error_state(e)
    # report it to eg honeybadger anyway, this should work.
    Rails.error.report(e)
  end

  def complete?
    status_success? || status_error?
  end

  # We asked Claude to tell us when it thinks it can't get an answer, did it?
  def llm_says_answer_unavailable?
    self.answer_json["answer_unavailable"] == true
  end

  # records and saves
  def record_error_state(e)
    self.status = :error
    self.error_info = {
      "exception_class" => e.class.name,
      "message" => e.message,
      "backtrace" => Rails.backtrace_cleaner.clean(e.backtrace).collect(&:to_json)
    }
    self.save!
  end


  # @param chunks [Array<OralHistoryChunk>] as fetched from neigbor gem, with a #neighbor_distance attribute
  def record_chunks_used(chunks)
    self.chunks_used = chunks.collect.with_index do |chunk, index|
      {
        "rank" => index + 1,
        "chunk_id" => chunk.id,
        "cosine_distance" => chunk.neighbor_distance.nan? ? 0 : chunk.neighbor_distance
      }
    end
  end
end
