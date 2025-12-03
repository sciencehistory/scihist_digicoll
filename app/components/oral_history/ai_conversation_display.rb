module OralHistory
  class AiConversationDisplay < ApplicationComponent
    # For admin output reporting, per million tokens. Claude Sonnet 4.5.AWS bedrock is same prices.
    # https://platform.claude.com/docs/en/about-claude/pricing
    OUTPUT_TOKEN_COST_PER_M = 15.0
    INPUT_TOKEN_COST_PER_M = 3.0

    delegate :can?, to: :helpers

    attr_reader :ai_conversation

    def initialize(ai_conversation)
      @ai_conversation = ai_conversation
    end

    def answer_narrative
      @answer_narrative ||= format_footnote_reference_html(@ai_conversation.answer_json["narrative"])
    end

    def footnote_list
      @footnote_list ||= build_footnote_data
    end

    def get_footnote_item_data(number)
      # perhaps could build a hash, this is fine for now
      footnote_list.find { |f| f.number == number.to_i }
    end

    # We have the hash from Claude with chunk ID's, we need
    # to fetch the chunks, use some data from each, we get a footnote
    def build_footnote_data
      chunk_ids = @ai_conversation.answer_json["footnotes"].collect {|h| h["chunk_id"]}
      chunks = OralHistoryChunk.where(id: chunk_ids).includes(oral_history_content: :work).strict_loading

      chunks_by_id = chunks.collect { |c| [c.id.to_s, c] }.to_h

      @ai_conversation.answer_json["footnotes"].collect do |response_hash|
        FootnoteItemData.new(response_hash: response_hash, chunk: chunks_by_id[response_hash["chunk_id"]])
      end
    end

    # find references that look like [^12] in the text, and replace with nice
    # HTML tags, producing SAFE html_safe on the way out
    def format_footnote_reference_html(narrative_text)
      # first make sure it's all html safe, cause we're gonna be slicing and dicing it
      narrative_text = Rails::HTML5::FullSanitizer.new.sanitize(narrative_text)

      # now replace footnote references with html doing all sorts of things
      # Use a separate component maybe?
      narrative_text.gsub!(/\[\^\d+\]/) do |reference|
        number = reference.slice(2, reference.length-2) # get rid of brackets
        footnote_item_data = get_footnote_item_data(number)

        <<~EOS
           <a href="##{footnote_item_data.anchor}"><span class="badge bg-primary rounded-pill">#{footnote_item_data.number}</span></a>
          <a target="_blank" href="#{work_path(footnote_item_data.work.friendlier_id)}" data-bs-toggle="popover" data-bs-trigger="hover focus" data-bs-placement="bottom" data-bs-content="“#{ERB::Util.html_escape footnote_item_data.quote}”">
            <span class="badge bg-secondary-subtle rounded-pill">#{footnote_item_data.short_citation_title} ~ #{footnote_item_data.nearest_timecode_formatted}</span>
          </a>
        EOS
      end.html_safe
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
      ai_conversation.answer_json.except("narrative", "footnotes").merge(ai_conversation.response_metadata)
    end

    def debug_chunks_list
      @debug_chunks_list ||= begin
        ids = ai_conversation.chunks_used.collect { |h| h["chunk_id"] }
        OralHistoryChunk.where(id: ids).in_order_of(:id, ids).includes(oral_history_content: :work).strict_loading
      end
    end

    # for admin debug info
    def cosine_distance_for_chunk(chunk_id)
      ai_conversation.chunks_used.find { |h| h["chunk_id"] == chunk_id }&.dig("cosine_distance")
    end

    class FootnoteItemData
      attr_reader :response_hash, :chunk

      def initialize(response_hash:,chunk:)
        @response_hash = response_hash
        @chunk = chunk

        unless @response_hash && @chunk
          raise ArgumentError.new("Missing response_hash or chunk")
        end
      end

      def work
        chunk.oral_history_content.work
      end

      def number
        response_hash["number"]
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

      def nearest_timecode_formatted
        # we could have more complicated algorithm to find best timestamp, but good enough
        # for now.
        @nearest_timecode_formatted ||= begin
          timestamp_info = chunk.other_metadata["timestamps"][paragraph_start.to_s]
          timestamp = timestamp_info["included"].first || timestamp_info["previous"]
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
