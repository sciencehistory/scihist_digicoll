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

  enum :status, { queued: "queued", in_process: "in_process", success: "success", error: "error" }

  def complete?
    success? || error?
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
