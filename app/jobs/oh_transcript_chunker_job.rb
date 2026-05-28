# Makes OH chunks with embeddings! This is slow and does cost money, using OpenAI API!
#
# Forr now only works with OHMS legacy transcripts, will have to be enhanced.
#
# Refuses to run if there are already chunks, cause that would create a real mess!
class OhTranscriptChunkerJob < ApplicationJob
  # In a local constnat only so we can stub to something different in tests
  CHUNKER_CLASS = OralHistory::TranscriptChunker

  def perform(oral_history_content, delete_existing: false, use_dummy_embedding: false, only_if_invalid: false)

    if only_if_invalid
      if OralHistory::ChunkValidator.new(oral_history_content, check_source_fingerprints: true).validate
        Rails.logger.info("#{self.class.name}: called with only_if_invalid, and oral history #{oral_history_content.id} is valid, so not creating chunks.")
        return
      end
    end

    if oral_history_content.oral_history_chunks.exists?
      if delete_existing
        oral_history_content.oral_history_chunks.delete_all
        oral_history_content.oral_history_chunks.reset # make sure we don't have cached old association
      else
        raise RuntimeError.new("Can't create chunks when chunks already exist! It would create a mess. Or use delete_existing:true to auto-delete. For OralHistoryContent #{oral_history_content.id}")
      end
    end

    CHUNKER_CLASS.new(oral_history_content: oral_history_content, allow_embedding_wait_seconds: 10).create_db_records(use_dummy_embedding: use_dummy_embedding)
  end

end
