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
    TIMECODE_REGEX = /\[(\d\d:\d\d:\d\d)\]/ # note capture group

    attr_reader :plain_text

    def initialize(plain_text:)
      @plain_text = plain_text
    end

    # @return OralHistoryContent::Paragraph
    def paragraphs
      @paragraphs ||= split_paragraphs
    end

    private

    def split_paragraphs
      last_speaker_name = nil
      current_speaker_name = nil
      paragraph_index = 1
      previous_timestamp = nil

      # some transcripts have paragraphs split only by 2 `\r` -- like 90s MacOS?  Not sure
      # where this comes from but okay. So two (or more) \r or two \n or two \r\n
      #
      # but then a few dozen transcripts also have only single newlines separating paragraphs, blah!
      # So we also allow a single newline IF followed by (regex lookeahead, not included in match) what
      # looks like a speaker label
      #      #
      speaker_start_of_line = /^[[:space:]]*[A-Z\-.\' ]+: / # adapted from OralHistoryContent::OhmsXml::LegacyTranscript::OHMS_SPEAKER_LABEL_RE

      trim_transcript(plain_text).split(/(?:(?:\r|\n|\r\n)\s*){2,}|(?=#{speaker_start_of_line.source})/).collect do |raw_paragraph|
        raw_paragraph.strip!

        # There is some metadata that comes not only at beginning but sometimes in the middle
        # after new tape/interview session. We don't want it.
        next if looks_like_metadata_line?(raw_paragraph)

        # Sometimes we have timecodes at beginning of lines/paragraphs.
        # If the whole paragraph is a timecode, then record it and move on
        if raw_paragraph =~ /\A#{TIMECODE_REGEX.source}\Z/
          previous_timestamp = OhmsHelper.parse_ohms_timestamp($1)
          next
        end

        current_speaker_name = nil
        # While this is not an OHMS transcript, the regex extracted from OHMS works well
        if raw_paragraph =~ /^[[:space:]]*([A-Z\-.\' ]+): /
          current_speaker_name = $1
        end

        # if it starts with a timecode, remove it from text, and record
        if raw_paragraph =~ /\A#{TIMECODE_REGEX.source}/
          previous_timestamp = OhmsHelper.parse_ohms_timestamp($1)
          raw_paragraph.sub!(/\A#{TIMECODE_REGEX.source}/, '')
        end

        paragraph = OralHistoryContent::Paragraph.new(speaker_name: current_speaker_name,
                                                      paragraph_index: paragraph_index,
                                                      text: raw_paragraph.strip,
                                                      previous_timestamp: previous_timestamp
                                                      )
        if paragraph.speaker_name.blank?
          paragraph.assumed_speaker_name = last_speaker_name
        end


        last_speaker_name = paragraph.speaker_name || paragraph.assumed_speaker_name
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

      # Sometimes there are abstracts and preface we don't want, trim everything before
      # the first line that looks like a speaker attribution -- bold, but it seems right.
      # non-greedy matcher, with lookahead
      plain_text.sub!(/\A.*?(?=#{OralHistoryContent::OhmsXml::LegacyTranscript::BARE_OHMS_SPEAKER_LABEL_RE.source})/m, '')

      # Interview may contain one or more [END OF INTERVIEW] or [END OF INTEVIEW N], but  we'll use
      # negative lookahead to skip anything after "last one, not another one after it"
      if plain_text =~ /\[END OF INTERVIEW( \d+)?\]/
        plain_text.gsub!(/\[END OF INTERVIEW( \d+)?\](?!.*\[END OF INTERVIEW).*/m, '')
      elsif plain_text =~ /\[END OF TAPE, SIDE \d+\]/
        # at least one does not have END OF INTERVIEW, but does have end of tape, trim after LAST one
        plain_text.sub!(/\[END OF TAPE, SIDE \d+\](?!.*\[END OF TAPE, SIDE \d+\]).*/m, '')
      elsif plain_text =~ /NOTES|INDEX/
        # But sometimes they don't have an [END OF INTERVIEW], but still have a NOTES and/OR INDEX?
        # On a line by itself, eliminate with everything afterwords.
        plain_text.gsub!(/^NOTES|INDEX$.*/m, '')
      end

      plain_text.strip!

      plain_text
    end
  end
end
