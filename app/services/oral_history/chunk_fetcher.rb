module OralHistory
  # Fetch OralHistoryChunks for RAG querying, from pg db, using `neighbor` gem for vector
  # search cosine similarity.
  #
  # Can also use fancy SQL to limit to only so many per document, and add
  # other constraints.
  class ChunkFetcher
    attr_reader :top_k, :question_embedding


    # @param k [Integer] how many chunks do you want back
    def initialize(top_k:, question_embedding:)
      @question_embedding = question_embedding
      @top_k = top_k
    end

    # @return [Array<OralHistoryChunk>]  Where each one also has a `neighbor_distance` attribute
    #     with cosine distance, added by neighbor gem. Set returned has strict_loading to ensure
    #     pre-loading to avoid n+1 fetch problem.
    def fetch_chunks
      # Preload work, so we can get title or other metadata we might want.
      OralHistoryChunk.neighbors_for_embedding(question_embedding).limit(top_k).includes(oral_history_content: :work).strict_loading
    end
  end
end
