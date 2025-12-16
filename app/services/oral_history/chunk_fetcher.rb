module OralHistory
  # Fetch OralHistoryChunks for RAG querying, from pg db, using `neighbor` gem for vector
  # search cosine similarity.
  #
  # Can also use fancy SQL to limit to only so many per document, and add
  # other constraints.
  class ChunkFetcher
    attr_reader :top_k, :question_embedding, :per_document_limit, :oversample_factor


    # @param top_k [Integer] how many chunks do you want back
    #
    # @param per_document_limit [Integer] if set, only include top per_document_limit
    #    per oral history.
    #
    # @param oversample_factor [Integer] When doing per_document_limit, we need to kind of originally
    #     fetch more than that, so we can then apply the per_document limit and still have enough.
    #     It all happens inside a SQL subquery, but we can't actually rank _everything_.
    def initialize(top_k:, question_embedding:, per_document_limit: nil, oversample_factor: 3)
      @top_k = top_k
      @question_embedding = question_embedding
      @per_document_limit = per_document_limit
      @oversample_factor = oversample_factor
    end

    # @return [Array<OralHistoryChunk>]  Where each one also has a `neighbor_distance` attribute
    #     with cosine distance, added by neighbor gem. Set returned has strict_loading to ensure
    #     pre-loading to avoid n+1 fetch problem.
    def fetch_chunks
      relation = if per_document_limit
        wrap_for_per_document_limit(base_relation: base_relation, per_document_limit: per_document_limit, inner_limit: oversample_factor * top_k)
      else
        base_relation
      end

      relation.limit(top_k).strict_loading
    end

    # Without limit count, we'll add that later.
    def base_relation
      OralHistoryChunk.neighbors_for_embedding(question_embedding).includes(oral_history_content: :work)
      # Preload work, so we can get title or other metadata we might want.
      #OralHistoryChunk.neighbors_for_embedding(question_embedding).includes(oral_history_content: :work)
    end

    # We need to take base_scope and use it as a Postgres CTE (Common Table Expression)
    # to select from, but adding on a ROW_NUMBER window function, that let's us limit
    # to top per_document_limit!
    #
    # Kinda tricky. Got from google and talking to LLMs.
    #
    # @return [ActiveRecord::Relation] that's been wrapped with a CTE to enforce per_document limits.
    def wrap_for_per_document_limit(base_relation:, per_document_limit:, inner_limit:)
      base_relation = base_relation.dup # cause we're gonna mutate it, avoid confusion.

      # add a 'select' using semi-private select_values API
      # Not sure what neighbor's type erialization is doing we couldn't get right ourselves, but it works.
      base_relation.select_values += [
        ActiveRecord::Base.sanitize_sql([
          "ROW_NUMBER() OVER (PARTITION BY oral_history_content_id ORDER BY oral_history_chunks.embedding <=> ?) as doc_rank",
          Neighbor::Type::Vector.new.serialize(question_embedding)
        ])
      ]

      # In the inner CTE, have to fetch oversampled, so we can wind up with
      # hopefully enough in outer. Leaving inner unlimited would be peformance,
      # cause of how indexing works it doesn't need to calculate them all.
      base_relation.limit(inner_limit)

      # copy the order from inner scope, where neighbor gem set it to be vector distance asc
      # We leave the real limit for the caller to set
      OralHistoryChunk.with(ranked_chunks: base_relation).
        select("*").
        from("ranked_chunks").
        where("doc_rank <= ?", per_document_limit).
        order("neighbor_distance")
    end
  end
end
