# Makes OH chunks with embeddings! This is slow and does cost money, using OpenAI API!
#
# Forr now only works with OHMS legacy transcripts, will have to be enhanced.
#
# Refuses to run if there are already chunks, cause that would create a real mess!
class OhTranscriptChunkerJob < ApplicationJob
  # In a local constnat only so we can stub to something different in tests
  CHUNKER_CLASS = OralHistory::TranscriptChunker


  # Just some default params, including by default not doing $$ API calls on staging.
  def self.perform_later_on_publish(oral_history_content)
    # because it's so expensive, we don't normally do real embedding API calls if not
    # in production -- even if someone has left API keys set!
    use_dummy_embedding = ScihistDigicoll::Env.lookup(:use_dummy_embedding_on_oh_publish)

    self.perform_later(oral_history_content,
      only_if_invalid: true,
      refresh_extracted_pdf_paragraphs: false,
      delete_existing: true,
      use_dummy_embedding: use_dummy_embedding
    )
  end

  # @param delete_existing [Boolean] default false. if true, existing chunks will be deleted before creating new ones. If false,
  #     will raise and refuse to create new if existing!
  #
  # @param use_dummy_embedding [Boolean] default false, if treu will not calculate real embedding vector
  #    ($ expensive, slow), but will use a fake dummy 0 vector. Mostly used for testing, makes
  #    chunks pretty useless.
  #
  # @param only_if_invalid [Boolean] default false. If true, we will do nothing if valid chunks already exist.
  #
  # @param refresh_extracted_pdf_paragraphs [Boolean]. default false. If true, will first
  #    create fresh extracted_pdf_paragraphs if it is possible and paragraphs are missing
  #    or not fresh.
  def perform(oral_history_content, delete_existing: false, use_dummy_embedding: false, only_if_invalid: false, refresh_extracted_pdf_paragraphs: false)

    if refresh_extracted_pdf_paragraphs
      members = oral_history_content.work.members
      transcript_asset = members.loaded? ? members.find {|a| a.role == "transcript" } : members.where(role: "transcript").first

      # if we have extracted_pdf_text_json and don't have fresh paragraphs stored, we must refresh
      if transcript_asset && transcript_asset.file_derivatives[:extracted_pdf_text_json].present? && (
            oral_history_content.extracted_pdf_paragraphs.nil? || !oral_history_content.extracted_pdf_paragraphs.fresh?(oral_history_content: oral_history_content)
         )
        Rails.logger.info("#{self.class.name}: refresh_extracted_pdf_paragraphs:true and needs paragraphs, so creating.")

        begin
          OralHistoryContent::ParagraphContainer.create(
            oral_history_content: oral_history_content,
            allow_failure_to_sync: true
          )
        rescue PdfParagraphSplitter::Error => e
          Rails.logger.error("#{self.class.name}: Could not create extracted_pdf_paragraphs: #{e}")
        end
      end
    end

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
