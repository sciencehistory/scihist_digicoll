# Makes OH chunks with embeddings! This is slow and does cost money, using OpenAI API!
#
# Forr now only works with OHMS legacy transcripts, will have to be enhanced.
#
# Refuses to run if there are already chunks, cause that would create a real mess!
class OhTranscriptChunkerJob < ApplicationJob
  def perform(oral_history_content, delete_existing: false)
    if oral_history_content.oral_history_chunks.exists?
      if force
        oral_history_content.oral_history_chunks.delete_all
      else
        raise RuntimeError.new("Can't create chunks when chunks already exist! It would create a mess. Or use delete_existing:true to auto-delete. For OralHistoryContent #{oral_history_content.id}")
      end
    end

    # check to make sure we are OHMS legacy, that's all we can do right now.
    unless oral_history_content.ohms_xml.present? && oral_history_content.ohms_xml.legacy_transcript.present?
      raise RuntimeError.new("We only know how to process legacy OHMS xml at present, can't process OralHistoryContent #{oral_history_content.id}")
    end

    OralHistory::OhmsLegacyTranscriptChunker.new(oral_history_content: oral_history_content, allow_embedding_wait_seconds: 10).create_db_records
  end

end
