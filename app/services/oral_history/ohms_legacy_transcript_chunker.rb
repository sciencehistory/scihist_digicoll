module OralHistory
  #
  # Divides transcript into "cbunks" with embeddings, and saves in DB as OralHistoryChunk
  #
  # We ideally want to keep a "Question" and "Answer" in the same chunk for context (and
  # a few transcripts have multiple interviewers or intervieweees!), but that is just done
  # approximately while also staying within a minimum and max word count for a chunk more strictly.
  #
  class OhmsLegacyTranscriptChunker
    # always want more than this many words
    LOWER_WORD_LIMIT = 380

    # if we're at this many, and next paragraph looks like an "Question" rather than
    # "Answer", end the chunk before the new Question.
    WORD_GOAL = 580

    # if next paragraph would take us over this many words, end the chunk even
    # in the middle of a speaker turn or splitting an answer and question
    UPPER_WORD_LIMIT = 880 #

    attr_reader :transcript,  :interviewee_names

    def initialize(transcript, interviewee_names:)
      unless transcript.kind_of?(OralHistoryContent::OhmsXml::LegacyTranscript)
        raise ArgumentError.new("transcript must be OralHistoryContent::OhmsXml::LegacyTranscript, but was #{transcript.class}")
      end

      @transcript = transcript

      # For matching to speaker names
      #@interviewee_names = work.creator.find_all { |c| c.category == "interviewee"}.collect { |c| c.value.split(",").first.upcase }
      @interviewee_names = interviewee_names
    end

    # Goes through transcript paragraphs, divides into chunks, based on turn and word goals
    #
    # @return [Array<Array<OralHistoryContent::OhmsXml::LegacyTranscript::Turn>>] array of arrays, where
    #    each array is a "chunk" consisting of one of more turns.
    def split_chunks
      chunks = [] # array of arrays of LegacyTranscript::Turn

      current_chunk = []
      paragraph_speaker_name = nil

      transcript.paragraphs.each do |paragraph|
        last_paragraph_speaker_name = paragraph_speaker_name

        # only change speaker name if we have one, otherwise leave last one
        paragraph_speaker_name = paragraph.speaker_name if paragraph.speaker_name.present?

        prospective_count = chunk_word_count(current_chunk) + paragraph.word_count

        if prospective_count < LOWER_WORD_LIMIT
          # We won't even be at lower limit, so add to chunk
          current_chunk << paragraph

        elsif prospective_count >= UPPER_WORD_LIMIT
          # We'd be above upper limit if we added to chunk, so end chunk and start new one
          chunks << current_chunk

          last_two_paragraphs = (chunks.last || []).last(2)
          current_chunk = last_two_paragraphs + [ paragraph ]

        elsif prospective_count >= WORD_GOAL &&
              !interviewee_names.find { |n| paragraph_speaker_name.end_with? n }  &&
              interviewee_names.find { |n| last_paragraph_speaker_name.end_with? n }
          # It's a speaker name change to somoene that isn't an interviewee (a question) and we're above
          # word goal, so great time to end the chunk and start a new one with the presumed question
          chunks << current_chunk

          last_two_paragraphs = (chunks.last || []).last(2)
          current_chunk = last_two_paragraphs + [ paragraph ]

        else
          # Add to current chunk, loop again until a condition above is met, maybe
          # we can get to speaker name change before max.
          #
          # We could get more sophisticated with lookahead and end if we are at
          # goal and aren't gonna find a speaker naem before max, but meh.
          current_chunk << paragraph

        end
      end
      chunks << current_chunk

      chunks
    end

    private

    # A chunk_array is an array of Paragraphs, just sums their word counts
    def chunk_word_count(chunk_array)
      chunk_array.collect(&:word_count).sum
    end
  end
end
