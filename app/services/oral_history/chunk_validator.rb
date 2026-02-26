module OralHistory
  class ChunkValidator
    class Error < StandardError
      attr_accessor :friendlier_id
      def initialize(msg, friendlier_id:nil)
        @friendlier_id = friendlier_id
        super(msg)
      end
    end

    attr_reader :oral_history_content, :chunks, :friendlier_id

    # @param oral_history_content [OralHistoryContent] should have many associations pre-loaded,
    #   with strict_loading enabled, to avoid n+1, if you are doing many of these!
    def initialize(oral_history_content)
      @oral_history_content = oral_history_content
      @chunks = oral_history_content.oral_history_chunks.sort_by(&:start_paragraph_number)
      @friendlier_id = oral_history_content.work.friendlier_id
    end

    # Returns true, or raises a OralHistory::ChunkValidator::Error
    def validate!
      if embargoed?
        if chunks.present?
          raise Error.new("Embargoed OH has #{chunks.count} chunks, should have none",
            friendlier_id: friendlier_id
          )
        end
      elsif !oral_history_content.work.published?
        # don't bother validating it, may not be complete etc.
        return true
      else
        unless chunks.present?
          raise_error("expected to have chunks, but does not")
        end

        unless chunks.first.start_paragraph_number == 1
          raise_error("first chunk #{chunks.first.id} should start at paragraph 1, but starts at p #{chunks.first.start_paragraph_number}")
        end

        # Actually count paragraphs and make sure we have enough, a bit expensive
        num_paragraphs = OralHistory::TranscriptChunker.new(oral_history_content: oral_history_content).num_paragraphs
        unless chunks.last.end_paragraph_number == num_paragraphs
          raise_error("last chunk #{chunks.last.id} should end at paragraph #{num_paragraphs}, but ends at p #{chunks.last.end_paragraph_number}")
        end

        validate_chunk_sequence
      end

      return true
    end

    # Have to check for presence of unpublished transcript , bad data model, see
    # https://github.com/sciencehistory/scihist_digicoll/issues/3253
    def embargoed?
      unless defined?(@embargoed)
        oral_history_content.available_by_request_off? &&
          transcript = oral_history_content.work.members.find {|a| a.role == "transcript"} &&
          (transcript.nil? || !transcript.published?)
      end
      @embargoed
    end

    def validate_chunk_sequence
      chunks.each_cons(2) do |firstc, nextc|
        # Allow one paragraph of overlap!
        unless firstc.end_paragraph_number >= nextc.start_paragraph_number
          raise_error("chunks not properly consecutive, missing content: chunk #{firstc.id} ends at p#{firstc.end_paragraph_number}, next chunk #{nextc.id} starts at p#{nextc.start_paragraph_number}")
        end

        unless firstc.start_paragraph_number <= firstc.end_paragraph_number
          raise_error("chunk #{firstc.id} has start/end paragraphs not properly ordered: #{firstc.start_paragraph_number},#{firstc.end_paragraph_number}")
        end

        unless firstc.text.present?
          raise_error("chunk #{chunk.id} has no text")
        end
      end
    end

    private

    def raise_error(msg)
      raise Error.new(msg, friendlier_id: friendlier_id)
    end

  end
end
