class OralHistoryContent

  # A model for an Oral History paragraph, used by the Chunker to make chunks.
  #
  # Different classes can create these, depending on what format of transcript they are creating
  # from (OHMS, plain text, etc)  in some cases there may be subsets.
  #
  # Some may create sub-classes specific to their format, but this is a general API for chunkers.
  class Paragraph
    attr_reader :transcript_id

    # @return [integer] 1-based index of paragraph in document
    attr_reader :paragraph_index

    attr_reader :text

    # @return [Array<Integer>] list of timestamps (as seconds) included in ths paragraph
    attr_accessor :included_timestamps

    # @return [Integer] timestamp in seconds of the PREVIOUS timestamp to this paragraph,
    #                   to latest the timestamp sure not to miss beginning of paragraph.
    attr_accessor :previous_timestamp

    # @return [String] when the paragraph has no speaker name internally, we guess/assume
    #    it has the same speaker as previous paragraph. Store such an assumed speaker name
    #    from previous paragraph here.
    attr_accessor :assumed_speaker_name

    # OHMS transcript sub-classes get these from OHMS transcript model classes
    attr_accessor :speaker_name, :text

    def initialize(text:, paragraph_index:, speaker_name:)
      @text = text
      @paragraph_index = paragraph_index
      @speaker_name = speaker_name
    end

    def word_count
      @word_count ||= OralHistoryContent::OhmsXml::LegacyTranscript.word_count(text)
    end
  end
end
