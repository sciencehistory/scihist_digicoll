module OralHistory
  class AiConversationDisplayComponent < ApplicationComponent
    delegate :link_from_ai_conversation_footnote, to: :helpers

    # For admin output reporting, per million tokens. Claude Sonnet 4.5.AWS bedrock is same prices.
    # https://platform.claude.com/docs/en/about-claude/pricing
    OUTPUT_TOKEN_COST_PER_M = 15.0
    INPUT_TOKEN_COST_PER_M = 3.0

    delegate :can?, to: :helpers

    attr_reader :ai_conversation

    def initialize(ai_conversation)
      @ai_conversation = ai_conversation
    end

    def introduction
      ai_conversation.answer_json&.dig("introduction").presence
    end

    # Hash that has metadata about finding, with "citations" array, with more hashes,
    # each of which also will be expanded witih a "citation_item_model" with CitationItem
    def findings_hashes
      @findings_hashes ||= ai_conversation.answer_json&.dig("findings").presence&.tap do |findings_hash_list|
        add_citation_objects(findings_hash_list)
      end
    end

    # We have the hash from Claude with chunk ID's, we need
    # to fetch the chunks, use some data from each, we get a footnote
    def add_citation_objects(findings_hash_list)
      findings_hash_list.each do |hash|
        hash["citations"].each do |citation_hash|
          chunk = preserved_chunks_list.find { |c| c.id == citation_hash["chunk_id"].to_i }
          citation_hash["citation_item_model"] = CitationItem.new(response_hash: citation_hash, chunk: chunk)
        end
      end
    end

    # for admin display
    def estimated_cost_in_dollars
      @estimated_cost_in_dollars ||= begin
        input_tokens = ai_conversation.response_metadata.dig("usage", "input_tokens")
        output_tokens = ai_conversation.response_metadata.dig("usage", "output_tokens")

        if input_tokens && output_tokens
         (input_tokens.to_f / 1_000_000 * INPUT_TOKEN_COST_PER_M ) + (output_tokens.to_f / 1_000_000 * OUTPUT_TOKEN_COST_PER_M)
        end
      end
    end

    def debug_output_items
      ai_conversation.answer_json.except("introduction", "findings", "conclusion").merge(ai_conversation.response_metadata).merge(
        # sometimes it gives us a narrative about why the answer was unavailable, that we aren't showing to user,
        # so merge that in too
        "introduction" => (introduction if @ai_conversation.llm_says_answer_unavailable?)
      ).compact
    end

    def preserved_chunks_list
      @preserved_chunks_list ||= ai_conversation.rehydrate_chunks_used!
    end

    def calculated_timings
      @calculated_timings ||= begin
        timings = @ai_conversation.timings || []

        start = Time.parse(timings.first.second).to_f if timings.first&.second

        timings.collect do |timing|
          [timing.first, Time.parse(timing.second).to_f - start]
        end.compact
      end
    end

    class CitationItem
      attr_reader :response_hash, :chunk

      def initialize(response_hash:,chunk:)
        @response_hash = response_hash
        @chunk = chunk

        unless @response_hash
          raise ArgumentError.new("Missing response_hash")
        end
        unless @chunk
          raise ArgumentError.new("Missing chunk")
        end
      end

      def work
        chunk.oral_history_content.work
      end

      def oral_history_content
        chunk.oral_history_content
      end

      def quote
        response_hash['quote']
      end

      def paragraph_start
        response_hash["paragraph_start"]
      end

      def paragraph_end
        response_hash["paragraph_end"]
      end

      def anchor
        "footnote-#{number}"
      end

      def ref_anchor
        "ref-#{anchor}"
      end

      def nearest_timecode_formatted
        # we could have more complicated algorithm to find best timestamp, but good enough
        # for now.
        @nearest_timecode_formatted ||= begin
          timestamp_info = chunk.other_metadata.dig("timestamps", paragraph_start.to_s)
          timestamp = timestamp_info&.dig("included", 0) || timestamp_info&.dig("previous")
          timestamp.present? ? OhmsHelper.format_ohms_timestamp(timestamp) : ""
        end
      end

      def short_citation_paragraphs
        [paragraph_start, paragraph_end].uniq.join("-")
      end

      # We use lastname(s), date(s)
      def short_citation_title
        @short_citation_title ||= begin
          names = work.creator.find_all { |c| c.category == "interviewee" }.collect { |c| c.value.split(",").first }

          dates = work.date_of_work.collect { |d| [d.start, d.finish]}.flatten.compact.collect {|d| d.slice(0, 4).presence }.compact.uniq.sort
          dates = [dates.first, dates.last].uniq.join("-")

          "#{names.to_sentence}, #{dates}"
        end
      end
    end
  end
end
