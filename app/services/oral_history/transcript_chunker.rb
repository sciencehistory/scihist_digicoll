module OralHistory
  #
  # Divides transcript into "cbunks" with embeddings, and saves in DB as OralHistoryChunk
  #
  # We ideally want to keep a "Question" and "Answer" in the same chunk for context (and
  # a few transcripts have multiple interviewers or intervieweees!), but that is just done
  # approximately while also staying within a minimum and max word count for a chunk more strictly.
  #
  class TranscriptChunker
    # always want more than this many words
    LOWER_WORD_LIMIT = 260

    # if we're at this many, and next paragraph looks like an "Question" rather than
    # "Answer", end the chunk before the new Question.
    WORD_GOAL = 395

    # if next paragraph would take us over this many words, end the chunk even
    # in the middle of a speaker turn or splitting an answer and question
    UPPER_WORD_LIMIT = 520

    # Batches of chunks to create
    BATCH_SIZE = 100

    EMBEDDING_RETRY_WAIT = 5

    attr_reader :interviewee_names, :oral_history_content

    # @attribute paragraphs [Array<OralHistoryContent::Paragraph>]
    attr_reader :paragraphs


    # @param allow_embedding_wait_seconds [Integer] if we exceed open ai rate limit for getting
    #    embedding, can we wait and try again? With maximum wait being this many seconds.
    #    Default 0, so, no.
    def initialize(oral_history_content:, allow_embedding_wait_seconds: 0)
      unless oral_history_content.kind_of?(OralHistoryContent)
        raise ArgumentError.new("argument must be OralHistoryContent, but was #{oral_history_content.class.name}")
      end

      @oral_history_content = oral_history_content

      # different ways of extracting paragraphs, they all should return array of OralHistoryContent::Paragraph
      @paragraphs = if oral_history_content.ohms_xml&.legacy_transcript.present?
        oral_history_content.ohms_xml.legacy_transcript.paragraphs

      elsif oral_history_content.ohms_xml
        # TODO, new style transcript
        raise ArgumentError.new("#{self.class.name} can only be used with OHMS transcripts if they are legacy: #{oral_history_content.inspect}")

      elsif oral_history_content.searchable_transcript_source.present?
        OralHistory::PlainTextParagraphSplitter.new(
          plain_text: oral_history_content.searchable_transcript_source
        ).paragraphs

      else
        raise ArgumentError.new("#{self.class.name} can't find paragraph source content for: #{oral_history_content.inspect}")
      end

      # For matching to speaker names, assume it's "lastname, first dates" type heading,
      # take last name and upcase
      @interviewee_names = oral_history_content.work.creator.
        find_all { |c| c.category == "interviewee"}.
        collect { |c| c.value.split(",").first.upcase }

      @allow_embedding_wait_seconds = allow_embedding_wait_seconds
    end



    def create_db_records(use_dummy_embedding: false)
      # array of arrays of paragraphs
      chunk_arrays = split_chunks

      # create in batches for efficient batch embedding fetching, and efficient
      # insertion in DB with transactions.
      chunk_arrays.each_slice(BATCH_SIZE) do |batch|
        records = batch.collect { |list_of_paragraphs| build_chunk_record(list_of_paragraphs) }

        # TODO, get embeddings, for now we use dummy
        if use_dummy_embedding
          records.each { |r| r.embedding = OralHistoryChunk::FAKE_EMBEDDING }
        else
          embeddings = begin
            OralHistoryChunk.get_openai_embeddings(*records.collect(&:text))
          rescue Faraday::TooManyRequestsError => e
            # got a 429 from openai,
            if should_retry_openai_rate_limit(e)
              retry
            else
              raise e
            end
          end

          if embeddings.count != records.count
            raise StandardError.new("Fetched OpenAI embeddings in batch, but count does not equal record count! #{embeddings.count}, #{records.count}")
          end

          0.upto(embeddings.count - 1) do |index|
            records[index].embedding = embeddings[index]
          end
        end

        # little bit easier on the DB to save em in batches in a transaction
        OralHistoryChunk.transaction do
          records.each { |r| r.save! }
        end
      end

      nil
    end

    # an openai rate limit exception. Logs it. Decides based on our max wait time
    # if it's wait-retryable.  Does the waiting if it is, and then returns true.
    #
    # Returns false if not wait-retyable cause we don't have enough wait time.
    def should_retry_openai_rate_limit(e)
      log_msg = "#{self.class.name}: Error getting embeddings? #{e}:"

      if @allow_embedding_wait_seconds > 0
        log_msg += "WILL RETRY AFTER WAIT: "
      else
        log_msg += "ABORTING: "
      end

      relevant_headers = e.response.headers.keys.select { |k| k.start_with?("retry") || k.start_with?("x-retry")}
      log_msg += "\n\n    #{ e.response.headers.to_h.slice(relevant_headers).inspect }"

      Rails.logger.warn(log_msg)

      if allow_embedding_wait_seconds > 0
        wait = [EMBEDDING_RETRY_WAIT, allow_embedding_wait_seconds].min
        @allow_embedding_wait_seconds = @allow_embedding_wait_seconds - wait
        sleep wait
        return true
      else
        return false
      end
    end

    # Goes through transcript paragraphs, divides into chunks, based on turn and word goals
    #
    # @return [Array<Array<OralHistoryContent::OhmsXml::LegacyTranscript::Turn>>] array of arrays,
    #    where the individual arrays are lists of Paragraphs, representing a "chunk" consisting of
    #    one or usually several paragraphs.
    def split_chunks
      chunks = [] # array of arrays of LegacyTranscript::Paragraph

      current_chunk = []
      paragraph_speaker_name = nil

      paragraphs.each do |paragraph|
        last_paragraph_speaker_name = paragraph_speaker_name

        # only change speaker name if we have one, otherwise leave last one
        paragraph_speaker_name = paragraph.speaker_name if paragraph.speaker_name.present?

        # How big will a chunk be if we add this paragraph to it?
        prospective_count = chunk_word_count(current_chunk) + paragraph.word_count

        # We won't even be at lower limit, so need to add to chunk to work towards it
        if prospective_count < LOWER_WORD_LIMIT
          current_chunk << paragraph

        # We'd be above upper limit if we added to chunk, so must end chunk and start new one
        elsif prospective_count >= UPPER_WORD_LIMIT
          chunks << current_chunk

          overlap_paragraphs = (chunks.last || []).last(1)
          current_chunk = overlap_paragraphs + [ paragraph ]

        # It's a speaker name change to someone that isn't an interviewee (we think it's a question,
        # not an answer) and we're above word goal, so great time to end the chunk and start a new
        # one with the presumed question. end_with? is used for some weird "multi-interviewee with
        # same name" use cases, good enough.
        elsif prospective_count >= WORD_GOAL &&
              !interviewee_names.find { |n| paragraph_speaker_name&.end_with? n }  &&
              interviewee_names.find { |n| last_paragraph_speaker_name&.end_with? n }
          chunks << current_chunk

          overlap_paragraphs = (chunks.last || []).last(1)
          current_chunk = overlap_paragraphs + [ paragraph ]

        # Otherwise, keep adding to current chunk, loop again until a condition above is met, maybe
        # we can get to speaker name change before max.
        #
        # We could get more sophisticated with lookahead and end if we are at
        # goal and aren't gonna find a speaker naem before max, but meh.
        else
          current_chunk << paragraph
        end
      end
      chunks << current_chunk # last one

      chunks
    end

    # @param list_of_paragraphs [Array<OralHistoryContent::OhmsXml::LegacyTranscript::Paragraph>]
    #
    # Takes list of paragraphs and builds an OralHistoryChunk ActiveRecord object for it, does not
    # yet save, to allow efficiencies in bulk saving. Will be an expensive AI call out to get
    # embedding, unless dummy_embedding true is given.
    #
    # Record will NOT have embedding filled out, to allow efficient future bulk fetching
    # of embedding by caller.
    #
    # @return [OralHistoryChunk] that is NOT persisted to db yet, just in memory.
    #
    def build_chunk_record(list_of_paragraphs)

      # timestamps are in number of seconds. Hash keyed by paragraph index
      # with timestamp info for that paragraph.
      #
      # Json standard says keys have to be strings, postgres will convert them if we like it or not
      paragraph_timestamps = list_of_paragraphs.collect do |paragraph|
        [
          paragraph.paragraph_index.to_s,
          {
            "included" => paragraph.included_timestamps,
            "previous" => paragraph.previous_timestamp
          }
        ]
      end.to_h

      # All speakers -- if the first paragraph isn't labelled, use assumed_speaker_name
      # recorded from previous paragraphs.
      speakers = [list_of_paragraphs.first.speaker_name || list_of_paragraphs.first.assumed_speaker_name] +
        list_of_paragraphs.slice(1, list_of_paragraphs.length).collect(&:speaker_name)
      speakers.compact!
      speakers.uniq!

      OralHistoryChunk.new(
        text: list_of_paragraphs.collect(&:text_with_forced_speaker_label).join("\n\n"),
        oral_history_content: oral_history_content,
        start_paragraph_number: list_of_paragraphs.first.paragraph_index,
        end_paragraph_number: list_of_paragraphs.last.paragraph_index,
        speakers: speakers,
        other_metadata: {
          "timestamps" => paragraph_timestamps
        }
      )
    end

    private

    # A chunk_array is an array of Paragraphs, just sums their word counts
    def chunk_word_count(chunk_array)
      chunk_array.collect(&:word_count).sum
    end
  end
end
