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
        wrap_relation_for_max_per_interview(
          base_relation: base_relation,
          max_per_interview: max_per_interview,
          inner_limit: oversample_factor * max_per_interview * top_k
        )
      else
        base_relation
      end

      # Preload work, so we can get title or other metadata we might want.
      relation.limit(top_k).includes(oral_history_content: :work).strict_loading
    end

    # Without limit count or includes pre-fetch, we'll add those later.
    def base_relation
      relation = OralHistoryChunk

      # only published works, which requires a join
      relation = relation.joins(oral_history_content: :work).where(work: { published: true })

      # Apply any limits to certain OH's
      #
      # NOTE:  We can't use full logic for elminating "fully embargoed" that we implemented in scopes,
      #        crashes postgres. See https://github.com/sciencehistory/scihist_digicoll/issues/3253
      #
      #        For now we RELY upon fully embargoed OH's not being chunked.
      #
      case access_limit
      when :immediate_ohms_only
        # right now all OHMS are immediate, so.
        relation = relation.joins(:oral_history_content).where.not(oral_history_content: { ohms_xml_text: [nil, ""]})
      when :immediate_only
        relation = relation.joins(:oral_history_content).where(oral_history_content: { available_by_request_mode: ["off", nil] })
      when :immediate_or_automatic
        relation = relation.joins(:oral_history_content).where(oral_history_content: { available_by_request_mode: ["off", "automatic"] })
      else
        # TODO not excluding totally embargoed, see https://github.com/sciencehistory/scihist_digicoll/issues/3253
      end

      # Add our nearnest neighbor embedding query!
      relation = relation.neighbors_for_embedding(question_embedding)

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
    # Kinda tricky, especially to do with good index usage. Got solution from google and talking
    # to LLMs, including having them look at pg explain/analyze output.
    #
    # @param base_relation [ActiveRecord::Relation] original relation, it can have joins and conditions.
    #   It MUST have already had vector distance ordering applied to it with `neighbor` gem.
    #
    # @param max_per_interview [Integer] maximum results to include per interview (oral_history_content_id)
    #
    # @param inner_limit [Integer] how many to OVER-FETCH in inner limit, to have enough even after
    #    applying max-per-interview.
    #
    # @return [ActiveRecord::Relation] that's been in a query to enforce max_per_interview limits. It does
    #   not have an overall limit set, caller should do that if desired, otherwise will be effectively
    #   limited by inner_limit.
    def wrap_relation_for_max_per_interview(base_relation:, max_per_interview:, inner_limit:)
      # In the inner CTE, have to fetch oversampled, so we can wind up with
      # hopefully enough in outer. Leaving inner unlimited would be peformance problem,
      # cause of how indexing works it doesn't need to calculate them all if limited.
      base_relation = base_relation.limit(inner_limit)

      # Now we have another CTE that assigns doc_rank within partitioned
      # interviews, from base. Raw SQL is just way easier here.
      partitoned_ranked_cte = Arel.sql(<<~SQL.squish)
        SELECT base.*,
          ROW_NUMBER() OVER (
            PARTITION BY oral_history_content_id
            ORDER BY neighbor_distance
          ) AS doc_rank
        FROM base
      SQL

      # A wrapper SQL that incorporates both those CTE's, limiting to
      # doc_rank of how many we want per-interview, and overall making sure to
      # again order by vector neighbor_distance that must already have been included
      # in the base relation.
      base_relation.klass
        .select("*") # just pass through from underlying CTE queries.
        .with(base: base_relation)
        .with(partitioned_ranked: partitoned_ranked_cte)
        .from("partitioned_ranked")
        .where("doc_rank <= ?", max_per_interview)
        .order(Arel.sql("neighbor_distance"))
    end
  end
end
