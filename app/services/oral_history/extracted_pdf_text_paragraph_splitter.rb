module OralHistory
  # take the structural extracted_pdf_text hash from ExtractPdfText, and try to get
  # just the actual interview transcript itself (no intro or suffix material), parsed
  # into our OralHistory::Paragraph objects.
  #
  # We do NOT currently parse footnote/endnotes out, they are a lot harder (esp over the years)
  #
  # Ended up having to handle some tricky edge cases, leading to a bit squirrely code:
  #
  # * Joins paragraphs split across page bounds
  #
  # * Finds page numbers in standard bottom of page and unusual old top-of-page locations,
  #   and strips and records in metadata
  #
  # * Finds internal timestamps in old `<T: N min>` format and new [hh:mm:ss] format,
  #   and records timestamp metadata.
  #
  # * handles timestamps taht reset after `[END OF AUDIO` markers, re-seqencing
  #  full-transcript timestamps.
  #
  class ExtractedPdfTextParagraphSplitter
    class Error < StandardError; end

    # any page beginning with one of these is deemed post-transcript material. Normalized
    # downcase.
    POST_TRANSCRIPT_HEADINGS = ['index', 'bibliography', 'publication list', 'notes']

    # Speaker names are VARIOUS in these historical things, we can't do too much more
    # than so many chars before a colon. Some are not all caps. Some have multiple words.
    # Some have hyphens!
    SPEAKER_NAME_RE = /\A([\p{Word}\- '`\.]{1,40}): */

    # [hh::mm::ss] and suck up spaces on either side. Usually found at beginning
    # of paragraph.
    NEW_STYLE_TIMECODE_RE  = /\A[[:space:]]*\[(\d+\:\d+:\d+)\][[:space:]]*/

    # <T: N min>  usually found in mid-paragraph.
    OLD_STYLE_TIMECODE_RE = /<T: (\d+) min>/

    # A paragraph consisting solely of a page number
    PAGE_NUMBER_RE = /\A(?:[Pp]age )?(\d+)\Z/

    # often it's own paragraph, but can also be mid-paragraph, maybe from zoom!
    END_OF_AUDIO_FILE_RE = /\[END OF (AUDIO, FILE)|(TAPE, SIDE) .*\]/

    # We insert these ourselves to mark page breaks inside a paragraph.
    # we make it legal html5 custom tag cause seems better. With placeholder for % interpolation.
    PAGE_BREAK_MARKER = "<PAGE-BREAK next='%s'></PAGE-BREAK>"

    attr_reader :extracted_pdf_text, :file_start_times


    # @param extracted_pdf_text [Hash] jsonable Hash of text and structural metadata from PDF
    #        as returned by OralHistory::ExtractPdftext
    #
    # @param validate [Boolean] default true, will validate extracted_pdf_text to a JSON schema.
    #
    # @param file_start_times [Hash] as if might come from metadata 'start_times' in an
    #   oral_history_content&.combined_audio_component_metadata. Eg
    #
    #       {
    #          uuid  => 0,
    #          uuid1 => 2837,
    #          uuid2 => 3723
    #       }
    #
    #    The key uuid is actually ignored, but the ORDER in hash matters, to represent
    #    actual order of files. While optional, if it is needed for accurate timestamps,
    #    it's required and you'll get an error.
    #
    def initialize(extracted_pdf_text:, validate: false, file_start_times: nil)
      unless extracted_pdf_text.kind_of?(Hash) && extracted_pdf_text["pages"].kind_of?(Array)
        raise ArgumentError.new("extracted_pdf_text: needs to be a hash matching ExtractPdfText::JSON_SCHEMER")
      end

      # We don't normally do cause it's already validated, but you can
      if validate
        ExtractPdfText.validate_extract_pdf_text_json(extracted_pdf_text)
      end

      @extracted_pdf_text = extracted_pdf_text
      @file_start_times = file_start_times
    end

    def paragraphs
      @paragraphs ||= create_paragraphs(extracted_pdf_text["pages"])
    end

    # @return [OralHistory::Paragraph]
    def create_paragraphs(extracted_pdf_text_pages)
      paragraphs = []

      first_index = find_page_1_index(extracted_pdf_text_pages)
      unless first_index
        raise Error.new("Could not find page 1 index")
      end

      timestamp_file_offset_index = 0

      (first_index..(extracted_pdf_text_pages.count - 1)).each do |page_index|
        page_json = extracted_pdf_text_pages[page_index]

        # dup em so we can modify the list to remove page numbers paragraphs. We don't
        # care about blocks for processing at the moment.
        page_paragraphs = page_json["blocks"].collect {|h| h["paragraphs"]}.flatten

        # usually on bottom, sometimes on top
        logical_page_number = extract_and_remove_logical_page_number(page_paragraphs)

        if page_index == first_index
          trim_first_page_prefatory(page_paragraphs)
        end

        # A heading htat matches the post-transcript material, we're done!
        if page_paragraphs.first&.dig("text")&.downcase&.strip&.in?(POST_TRANSCRIPT_HEADINGS)
          break
        end

        next if page_paragraphs.empty?

        # Analyze paragraphs for [END OF AUDIO] mark to assign proper file offset index,
        # and update our current index if it got incremented.
        timestamp_file_offset_index =
          assign_timestmap_file_offset_index(page_paragraphs, timestamp_file_offset_index)

        # Turn from hashes to good objects
        page_paragraph_objects = page_paragraphs.collect do |paragraph_json|
          json_to_paragraph(paragraph_json, logical_page_number: logical_page_number)
        end

        remove_footnotes(page_paragraph_objects)

        # Should the first paragraph be joined to the last paragraph of the prior page, does
        # it look like a split paragraph?
        last_paragraph = paragraphs.last

        if last_paragraph && last_paragraph.text !~ (/\.?\!\Z/) && page_paragraph_objects.first.speaker_name.blank?
          # first doesn't end punctuation, and second doesn't begin with a speaker label? let's join em
          last_paragraph.text = [
            last_paragraph.text,
            page_paragraph_objects.first.text
          ].join(" #{PAGE_BREAK_MARKER % logical_page_number} ")

          # and remove the first paragraph from our list for this page
          page_paragraph_objects.shift
        end

        # And now add em all to big paragraph list!
        paragraphs.concat(page_paragraph_objects)
      end

      # add in 1-based paragraph indexes
      paragraphs.each_with_index { |p, i| p.paragraph_index = i + 1 }

      # Make sure everyone has an assumed speaker if they didn't have a speaker,
      # just keep it going from previous paragraph.
      paragraphs.each_cons(2) do |p1, p2|
        # if it begins with `[` it's a note like "[END OF TAPE]" and not an utterance
        if p2.speaker_name.nil? && !p2.text&.start_with?('[')
          p2.assumed_speaker_name = p1.speaker_name || p1.assumed_speaker_name
        end
      end

      return paragraphs
    end

    # Block with only one paragraph, whose whole text is a integer page number (possibly preceded
    # by 'Page') -- we don't worry  about roman numerals for now, cause all of those are prefatory
    # material we don't care about at the moment.
    #
    # @return [False,Integer] if it's a page number block, Integer page number extracted, otherwise false.
    def block_is_page_number(json_block)
      return false unless json_block

      if json_block["paragraphs"].count == 1 && (json_block["paragraphs"].first["text"] =~ PAGE_NUMBER_RE)
        return $1.to_i
      else
        return false
      end
    end

    # index in array of page with numeral "1" as page number, can be at top or bottom
    def find_page_1_index(pages)
      pages.find_index do |page_json|
        block_is_page_number(page_json["blocks"]&.last).to_s == "1" ||
        block_is_page_number(page_json["blocks"]&.first).to_s.downcase.in?([ "1", "page 1"])
      end
    end

    # The first page has "INTERVIEWER(S):", etc, which vary, but we think
    # always END with "DATE:", so we use that to trim em all
    def trim_first_page_prefatory(paragraph_json_list)
      date_header_index = paragraph_json_list.index { |p| p["text"]&.upcase&.start_with?("DATE:") }

      # now trim everything up to there please
      if date_header_index
        paragraph_json_list.slice!(0..date_header_index)
      end
    end

    # if a pagination marking paragraph is identified , we return the page number
    # extracted, and mutate page_paragraphs_json to remove it. Otherwise return nil.
    def extract_and_remove_logical_page_number(page_paragraphs_json)
      if page_paragraphs_json.last["text"].strip =~ PAGE_NUMBER_RE
        logical_page_number = $1.to_i
        page_paragraphs_json.pop
      elsif page_paragraphs_json.first["text"].strip =~ PAGE_NUMBER_RE
        logical_page_number = $1.to_i
        page_paragraphs_json.shift
      end

      return logical_page_number
    end

    # @param paragraphs_json [Array<Hash>] of a single page's paragraph jsons.
    #
    # If the LAST one(s) look like footnotes, skip em. Looks like a footnote
    # if it begins with "*" or a number -- doesn't catch too much in our
    # domain.
    def remove_footnotes(paragraphs_json)
      if paragraphs_json.last.text.strip =~ /\A(\*|\d+)/
        # looks like a footnote, we just toss it out, but maybe later we'll keep it
        # to try to turn into endnotes.
        reference = $1
        paragraphs_json.pop
      elsif note_index = (paragraphs_json.last.text =~ /_{15,} ?\*/)
        # OKAY, weird one for Prelog asterisk not split by paragraph but
        # with a big line separator first, argh.
        # eg:
        #     ____________________________________ *Footnote

        # we need to cut that last paragraph to stop there
        paragraphs_json.last.text.slice!(note_index..-1)
      end
    end


    # Analyze paragraphs for [END OF AUDIO] mark to assign proper file offset index,
    # and update our current index.
    #
    # @param page_paragrahs [Array<Hash>] of json page paragraphs. Will mutate to add
    # `timestamp_file_offset_index` key
    #
    # @param timestamp_file_offset_index [Integer] initial
    #
    # @return [Integer] updated timestamp_file_offset_index
    #
    def assign_timestmap_file_offset_index(page_paragraphs, timestamp_file_offset_index)
      page_paragraphs.each do |paragraph_json|

        paragraph_json["timestamp_file_offset_index"] = timestamp_file_offset_index

        # OFten it's own paragraph, but can also be mid-paragraph, perahps from zoom!
        if paragraph_json["text"] =~ END_OF_AUDIO_FILE_RE
          timestamp_file_offset_index += 1
        end
      end

      return timestamp_file_offset_index
    end

    def json_to_paragraph(paragraph_json, logical_page_number:)
      text = paragraph_json["text"]

      # look for new style timecode as prefix
      if text.sub!(NEW_STYLE_TIMECODE_RE, '')
        timestamp = OhmsHelper.parse_ohms_timestamp($1)
      elsif text =~ OLD_STYLE_TIMECODE_RE
        # look for timecode in old style <T: \d min> thing, leave
        # in text in case we want to mark exact timecode location later
        timestamp = $1.to_i * 60
      end

      # adjust for offset if it's got a file offset index recorded, can apply to newstyle and old
      if timestamp && (current_index = paragraph_json["timestamp_file_offset_index"].to_i) != 0
        # we need to add on the start time of current non-0 segment
        offset = file_start_times&.values&.dig(current_index)

        unless offset.present?
          raise Error.new("Could not find file start time offset for index #{current_index.inspect} in offsets #{file_start_times.inspect}")
        end

        timestamp += offset
      end

      # Do we have a speaker name? Remove it from text but record it as speaker name.
      if text.sub!(SPEAKER_NAME_RE, '')
        speaker_name = $1.upcase.strip
      end

      OralHistoryContent::Paragraph.new(
        speaker_name: speaker_name,
        text: text,
        paragraph_index: nil, # we'll add them in later
        pdf_logical_page_number: logical_page_number,
        included_timestamps: [timestamp].compact.presence
      )
    end
  end
end
