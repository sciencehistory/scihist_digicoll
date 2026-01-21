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

  before_save do
    # record git SHA of the current codebase, to give us a chance to know what logic
    # generated this, for comparison.
    self.project_source_version ||= ENV['SOURCE_VERSION']
  end

  # Actually talk to Claude based on question preserved here, and record answer and metadata as
  # we go. This could take 10+ seconds, so is usually done in a background job.
  #
  # This will do possibly multiple save!s of self to save state.
  def exec_and_record_interaction
    # if it's done or has an in_process, then refuse to do it again. But we can retry an error.
    unless status_queued? || status_error?
      raise RuntimeError.new("can't exec_and_record_interaction on status #{status}")
    end

    self.add_timing("start")

    # Get and save embedding if it's not already there (it costs money, so we want to cache it!),
    # and set status to in_process
    self.question_embedding ||= OralHistoryChunk.get_openai_embedding(self.question)
    self.status = :in_process
    self.error_info = nil # in case it was error state before
    self.save!

    # Start the conversation, could take 10-20 seconds even.
    interactor = OralHistory::ClaudeInteractor.new(
      question: self.question,
      question_embedding: self.question_embedding,
      access_limit: search_params&.dig("access_limit").presence && search_params["access_limit"].to_sym
    )

    response = interactor.get_response(conversation_record: self)

    self.answer_json = interactor.extract_answer(response)
    self.status = :success
    self.add_timing("finish")
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
    self.answer_json&.dig("answer_unavailable") == true
  end

  def answer_narrative
    answer_json&.dig("narrative").presence
  end

  # Array of hashes, the format of the hash is still not formally specified, sorry
  def answer_footnotes_json
    answer_json["footnotes"]
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


  # @param chunks [Array<Hash>] json serialized OralHistoryChunk as fetched from neigbor gem,
  #   with a #neighbor_distance attribute
  def record_chunks_used(chunks)
    # we are going to record the whole chunk, so we can still show historical Q&A if chunks in db
    # have changed. especially relevant when we're prototyping and testing.
    #
    # Chunks should already have "neighbor_distance" attribute with cosine distance.  Order is preserved.
    #
    # We also use chunks metadata for citation references, so we know what paragraph etc.
    #
    # We remove `embedding` cause it is huge and we don't need original embedding vector.
    self.chunks_used = chunks.collect do |chunk|
      chunk.as_json.except("embedding")
    end
  end

  # Deserializes json self.chunks_used to OralHistoryChunks, taking care of some legacy data.
  #
  # May go to DB for legacy data, could be an expensive operation.
  #
  # @return [Array<OralHistoryChunk>] ordered by original presence in chunks_used, which
  #     should be original ranking. Should have neighbors_present serialized from original
  #     chunks_used.
  def rehydrate_chunks_used!
    # Do we need to try to fetch Chunks from the db for incomplete legacy
    # hashes?  If so, they NEED to be in DB, or we're gonna error.
    legacy_hashes = chunks_used.find_all { |h| h["chunk_id"].present? }
    if legacy_hashes
      fetched_chunks = OralHistoryChunk.find(legacy_hashes.collect { |h| h["chunk_id"].to_i })
    end

    self.chunks_used.collect do |attributes|
      if attributes["chunk_id"].present?
        # old stored format that was not a serialized model,
        # to at least partial serialized model.
        fetched_chunks.find { |c| c.id == attributes["chunk_id"]}
      else
        # doc_rank winds up in there from our weird sql, but isn't an attribute
        attributes.delete("doc_rank")
        # we didn't serialize long vector embedding we don't need, but let's add in
        # a fake one just to make it a valid record.
        attributes["embedding"] ||= OralHistoryChunk::FAKE_EMBEDDING
        OralHistoryChunk.new(attributes)
      end
    end.tap do |list|
      # preload their works please
      ActiveRecord::Associations::Preloader.new(
        records: list,
        associations: { oral_history_content: :work }
      ).call

      # and make em all strict loading so we can't load any more n+1
      list.each(&:strict_loading!)

      # and prevent saving, these are preserved historical records
      list.each(&:readonly!)
    end
  end

  def add_timing(label, timestamp=Time.now)
    self.timings << [label, timestamp.utc.iso8601(3)]
  end
end
