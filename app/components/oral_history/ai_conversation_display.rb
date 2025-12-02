module OralHistory
  class AiConversationDisplay < ApplicationComponent
    attr_reader :ai_conversation

    def initialize(ai_conversation)
      @ai_conversation = ai_conversation
    end

    def answer_narrative
      simple_format @ai_conversation.answer_json["narrative"]
    end

    def footnote_list
      @footnote_list ||= build_footnote_data
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
