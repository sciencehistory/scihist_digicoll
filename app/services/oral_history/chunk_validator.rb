module OralHistory
  class ChunkValidator
    class Failure < StandardError
      attr_accessor :friendlier_id
      def initialize(msg, friendlier_id:nil)
        @friendlier_id = friendlier_id
        super(msg)
      end
    end

    attr_reader :oral_history_content, :chunks, :friendlier_id, :check_source_fingerprints

    # Does some weird SQL tricks to efficiently get the list of UNIQUE source_fingerprints from related chunks
    # to an OralHistoryContent.
    #
    # They will be json strings in attribute `uniq_source_fingerprints` on each OralHistoryContent,
    # load from json and we can check for freshness of all extant chunks
    #
    # @example
    #
    #     scope = OralHistoryContent.where(something)
    #     scope = OralHistoryChunkValidator.with_uniq_source_fingerprints(scope)
    #     oc = scope.first
    #     source_fingerprints = oc.uniq_source_fingerprints.collect { |s| JSON.parse(s) }
    #
    def self.with_uniq_source_fingerprints(scope)
      unless scope.model_name.name == "OralHistoryContent"
        raise ArgumentError.new("can only work with an OralHistoryContent not a #{scope&.model_name&.name || scope.class.name}")
      end

      scope.joins(:oral_history_chunks).
        select("oral_history_content.*", "array_agg(DISTINCT oral_history_chunks.other_metadata ->> 'source_fingerprint') AS uniq_source_fingerprints").
        group("oral_history_content.id")
    end

    # @param oral_history_content [OralHistoryContent] should have many associations pre-loaded,
    #   with strict_loading enabled, to avoid n+1, if you are doing many of these!
    def initialize(oral_history_content, check_source_fingerprints: true)
      @oral_history_content = oral_history_content
      @chunks = oral_history_content.oral_history_chunks
      @friendlier_id = oral_history_content.work.friendlier_id
      @check_source_fingerprints = !! check_source_fingerprints

      unless oral_history_content
        raise ArgumentError.new("oral_history_content must not be nil")
      end
    end

    # Returns true, or raises a OralHistory::ChunkValidator::Failure
    def validate!
      if embargoed?
        if chunks.present?
          raise_error("Embargoed OH has #{chunks.length} chunks, should have none")
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

      if check_source_fingerprints
        uniq_source_fingerprints = if oral_history_content.oral_history_chunks.loaded?
          oral_history_content.oral_history_chunks.collect { |c| c.other_metadata["source_fingerprint"] }.uniq
        elsif oral_history_content.respond_to?(:uniq_source_fingerprints)
          oral_history_content.uniq_source_fingerprints
        else
          raise ArgumentError.new(<<~EOS)
            Cannot check_source_fingerprints. Need one of:
            * `uniq_source_fingerprints` attribute, see .with_uniq_source_fingerprints to prepare scope for fetch
            * pre-fetch/load oral_history_chunks
            * set check_source_fingerprints: false to skip
          EOS
        end

        fresh_fingerprint = OralHistory::TranscriptChunker.new(oral_history_content: oral_history_content).computed_source_fingerprint

        passed, failed = uniq_source_fingerprints.partition do |source_fingerprint|
          # is it fresh with one we compute now?
          fresh_fingerprint == source_fingerprint
        end

        unless passed.present?
          raise_error("Chunks do not have fresh source_fingerprint. Expected: #{fresh_fingerprint.inspect} ; Actual: #{failed.inspect}")
        end
        if failed.present?
          raise_error("Some chunks do not have fresh source_fingerprint. Expected: #{fresh_fingerprint.inspect} ; Actual: #{failed.inspect}")
        end
      end

      return true
    end

    # Have to check for presence of unpublished transcript , bad data model, see
    # https://github.com/sciencehistory/scihist_digicoll/issues/3253
    def embargoed?
      unless defined?(@embargoed)
        @embargoed = oral_history_content.available_by_request_off? &&
          (transcript = oral_history_content.work.members.find {|a| a.role == "transcript"}) &&
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
      raise Failure.new(msg, friendlier_id: friendlier_id)
    end

  end
end
