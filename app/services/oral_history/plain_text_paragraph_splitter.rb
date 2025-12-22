module OralHistory
  # Takes a plain text OH transcript, such as included for searching in the OralHistoryContent#searchable_transcript_source
  # field, and splits it into OralHistoryContent::Paragraph objects, for use by chunker.
  #
  # Note that this does not let us know what PDF page the paragraph is on, which might be nice
  # for citing. And we have no timestamps, no sync timestamps in these transcripts.
  #
  # This may be a temporary interim implementation, to demo AI vector search of this content,
  # while we figure out how we want to do better citing/linking.
  #
  class PlainTextParagraphSplitter
    attr_reader :plain_text, :oral_history_id

    def initialize(plain_text:, oral_history_id:)
      @plain_text = plain_text
      @oral_history_id = oral_history_id
    end

    # @return OralHistoryContent::Paragraph
    def paragraphs
      @paragraphs ||= split_paragraphs
    end

    private

    def split_paragraphs
      last_speaker_name = nil
      current_speaker_name = nil
      paragraph_index = 0

      things = trim_transcript(plain_text).split(/(?:\r?\n\s*){2,}/).collect do |raw_paragraph|
        raw_paragraph.strip!

        # There is some metadata that comes not only at beginning but sometimes in the middle
        # after new tape/interview session. We don't want it.
        next if looks_like_metadata_line?(raw_paragraph)

        current_speaker_name = nil
        # While this is not an OHMS transcript, the regex extracted from OHMS works well
        if raw_paragraph =~ OralHistoryContent::OhmsXml::LegacyTranscript::OHMS_SPEAKER_LABEL_RE
          current_speaker_name = $1.chomp(":")
        end

        paragraph = OralHistoryContent::Paragraph.new(speaker_name: current_speaker_name,
                                                      paragraph_index: paragraph_index,
                                                      text: raw_paragraph,
                                                      transcript_id: oral_history_id)
        if paragraph.speaker_name.blank?
          paragraph.assumed_speaker_name = last_speaker_name
        end


        last_speaker_name = current_speaker_name
        paragraph_index +=1

        paragraph
      end.compact
    end

    def looks_like_metadata_line?(str)
      # if it's one line, with one of our known metadata labels, colon, some info
      str =~ /\A\s*(INTERVIEWEE|INTERVIEWER|DATE|LOCATION):.+$/ ||
        # Also for now just avoid the [END OF ...] markers.
        str =~ /\A\[END OF INTERVIEW.*\]\s*$/ ||
        str =~ /\A\[END OF TAPE.*\]\s*$/
    end

    # Trim END after last [END OF INTERVEW] marker -- get rid of footnote and index.
    def trim_transcript(plain_text)
      plain_text = plain_text.dup

      # we sometimes have unicode BOM and nonsense in there
      plain_text.gsub!(/[\u200B\uFEFF]/, '')

      # Interview ends with [END OF INTERVIEW] *or* [END OF INTERVIEW 4] etc.
      # We want to strip the LAST one in the transcript and anythi8ng after it
      # , we'll use negative lookahead to be "last one, not another one after it"
      plain_text.gsub!(/\[END OF INTERVIEW( \d+)?\](?!.*\[END OF INTERVIEW).*/m, '').strip

      plain_text
    end
  end
end
