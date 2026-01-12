module OralHistory
  # Fetch OralHistoryChunks for RAG querying, from pg db, using `neighbor` gem for vector
  # search cosine similarity.
  #
  # Can also use fancy SQL to limit to only so many per document, and add
  # other constraints.
  class ChunkFetcher
    ACCESS_LIMITS = %i{immediate_ohms_only immediate_only immediate_or_automatic} + [nil] # symbols

    attr_reader :top_k, :question_embedding, :max_per_interview, :oversample_factor, :access_limit
    attr_reader :exclude_oral_history_chunk_ids, :exclude_oral_history_content_ids


    # @param top_k [Integer] how many chunks do you want back
    #
    # @param max_per_interview [Integer] if set, only include top per document_limit
    #    per oral history.
    #
    # @param oversample_factor [Integer] When doing max_per_interview, we need to kind of originally
    #     fetch more than that, so we can then apply the max_per_interview limit and still have enough.
    #     It all happens inside a SQL subquery, but we can't actually rank _everything_.
    #
    # @param exclude_chunks [Array<OralHistoryChunk,Integer>] Array of OralHistoryChunk, or OralHistoryChunk#id, exclude these
    #
    # @param exclude_interviews [Array<Work,OralHistoryContent,Integer>] Interviews to exclude. can be as Work, OralHistoryContent,
    #   or OralHistoryContent#id
    #
    # @param access_limit [Symbol,nil] should we limit to only certain oral histories? Either on
    #   having OHMS attached, or on access/availability level. See ACCESS_LIMITS for values.
    def initialize(top_k:, question_embedding:,
        access_limit: nil,
        max_per_interview: nil,
        oversample_factor: 3,
        exclude_chunks: nil,
        exclude_interviews: nil)
      @top_k = top_k
      @question_embedding = question_embedding
      @max_per_interview = max_per_interview
      @oversample_factor = oversample_factor


      @access_limit = access_limit
      unless @access_limit.in?(ACCESS_LIMITS)
        raise ArgumentError.new("access_limit is #{access_limit.inspect}, but must be in #{ACCESS_LIMITS.inspect}")
      end

      if exclude_chunks
        @exclude_oral_history_chunk_ids = exclude_chunks.collect {|i| i.kind_of?(OralHistoryChunk) ? i.id : i }
      end

      if exclude_interviews
        @exclude_oral_history_content_ids = exclude_interviews.collect do |i|
          if i.kind_of?(Work)
            i.oral_history_content.id
          elsif i.kind_of?(OralHistoryContent)
            i.id
          else
            i
          end
        end
      end
    end

    # @return [Array<OralHistoryChunk>]  Where each one also has a `neighbor_distance` attribute
    #     with cosine distance, added by neighbor gem. Set returned has strict_loading to ensure
    #     pre-loading to avoid n+1 fetch problem.
    def fetch_chunks
      relation = if max_per_interview
        wrap_relation_for_max_per_interview(base_relation: base_relation, max_per_interview: max_per_interview, inner_limit: oversample_factor * top_k)
      else
        base_relation
      end

      relation.limit(top_k).strict_loading
    end

    # Without limit count, we'll add that later.
    def base_relation
      relation = OralHistoryChunk

      # Apply any limits to certain OH's
      case access_limit
      when :immediate_ohms_only
        # right now all OHMS are immediate, so.
        relation = relation.joins(:oral_history_content).merge(OralHistoryContent.with_ohms)
      when :immediate_only
        relation = relation.joins(:oral_history_content).merge(OralHistoryContent.available_immediate)
      when :immediate_or_automatic
        relation = relation.joins(:oral_history_content).merge(OralHistoryContent.available_immediate).or( OralHistoryContent.upon_request )
      else
        # still need to exclude totally private, although we shoudln't have any chunks made
        # for these anyway, it's important enough we want to be sure! Hopefully won't hurt performance too bad.
        # TODO
        relation = relation.joins(:oral_history_content).merge(OralHistoryContent.all_except_fully_embargoed)
      end

      # Add our nearnest neighbor embedding query!
      relation = relation.neighbors_for_embedding(question_embedding)

      # Preload work, so we can get title or other metadata we might want.
      relation = relation.includes(oral_history_content: :work)

      # exclude specific chunks?
      if exclude_oral_history_chunk_ids.present?
        relation = relation.where.not(id: exclude_oral_history_chunk_ids)
      end

      # exclude interviews?
      if exclude_oral_history_content_ids.present?
        relation = relation.where.not(oral_history_content_id: exclude_oral_history_content_ids)
      end

      relation
    end

    # We need to take base_scope and use it as a Postgres CTE (Common Table Expression)
    # to select from, but adding on a ROW_NUMBER window function, that let's us limit
    # to top max_per_interview
    #
    # Kinda tricky. Got from google and talking to LLMs.
    #
    # @return [ActiveRecord::Relation] that's been wrapped with a CTE to enforce max_per_interview limits.
    def wrap_relation_for_max_per_interview(base_relation:, max_per_interview:, inner_limit:)
      # We are creating a SQL of this form:
      #
      #     WITH ranked_chunks AS (
      #     SELECT
      #             chunks.*,
      #             chunks.embedding <=> ? as distance,
      #             ROW_NUMBER() OVER (PARTITION BY document_id ORDER BY chunks.embedding <=> ?) as doc_rank
      #           FROM chunks
      #           ORDER BY chunks.embedding <=> ?
      #           LIMIT <big limit to get enough to choose from>
      #     )
      #         SELECT *
      #         FROM ranked_chunks
      #         WHERE doc_rank <= <max_per_interview>
      #         ORDER BY distance
      #         LIMIT <actual limit>
      #
      # Where the thing inside teh ranked_chunks CTE is the original neighbor query (base_relation),
      # with the ROW_NUMBER and a limit added to it

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
        where("doc_rank <= ?", max_per_interview).
        order("neighbor_distance").
        includes(oral_history_content: :work)
    end
  end
end
