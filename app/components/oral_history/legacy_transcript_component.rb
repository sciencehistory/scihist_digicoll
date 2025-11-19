module OralHistory
  # Turn OHMS XML into HTML, using tags based on OHMS native viewer, at
  # around OHMS version ~3.8.
  #
  # Takes a OralHistoryContent::OhmsXml::LegacyTranscript with LEGACY kind of OHMS XML, with
  # <ohms:sync> and <ohms:transcript> elements.
  #
  # Includes timestamp tags at appropriate place, from <sync> data.
  #
  # Input is our OralHistoryContent::OhmsXml wrapper/helper object.
  class LegacyTranscriptComponent < ApplicationComponent
    OHMS_NS = OralHistoryContent::OhmsXml::OHMS_NS

    delegate :format_ohms_timestamp, to: :helpers

    attr_reader :legacy_transcript, :references_already_output, :transcript_log_id

    # @param legacy_transcript [OralHistoryContent::OhmsXml::LegacyTranscript]
    # @param ohms_transcript_id [String] just for identification in error messages
    def initialize(legacy_transcript, transcript_log_id:)
      @legacy_transcript = legacy_transcript
      @references_already_output = Set.new()
      @transcript_log_id = transcript_log_id
    end

    # Trying to display somewhat like OHMS does. We need to track lines separated by individual "\n", that
    # matches line count in `sync`. But we also need to group lines separated by "\n\n" into paragraphs.
    # "\n\n" does mean an empty line as far as line count.
    #
    # We're also doing things somewhat different than OHMS when we coudn't figure out why it made
    # any sense (like a bare span for an empty line, or using span as a wrapper for p which is
    # probably illegal HTML)
    #
    # OhmsXmlValidator is in charge of validating the footnotes at
    # upload time and rejecting ones that are invalid.
    # We can thus assume the footnotes are valid at display time;
    # if the array of footnotes doesn't contain a footnote for `number`,
    # we are *not* going to throw an error.
    def call


      paragraph_html_arr = legacy_transcript.paragraphs.collect do |paragraph|
        content_tag("div", class: "ohms-transcript-paragraph-wrapper") do
          content_tag("p", class: "ohms-transcript-paragraph") do
            safe_join(paragraph.lines.collect do |line|
              content_tag("span", format_ohms_line(line),
                class: "ohms-transcript-line",
                  id: "ohms_line_#{line.line_num}",
                  "data-searchable-transcript-line" => true)
            end)
          end
        end
      end

      transcript_html = content_tag("div", safe_join(paragraph_html_arr), class: "ohms-transcript-container")

      if legacy_transcript.footnote_array.present?
        transcript_html << content_tag("div") do
          render OralHistory::FootnotesSectionComponent.new(footnote_array: legacy_transcript.footnote_array)
        end
      end

      transcript_html
    end


    # lookup footnote text that's been parsed from transcript,
    # ensuring empty string instead of nil, and logging a warning
    # if we can't find it.
    def footnote_text_for(number)
      footnote_text = legacy_transcript.footnote_array[number.to_i - 1]  || ''

      if footnote_text == ''
        Rails.logger.warn("WARNING: Reference to empty or missing footnote #{number} for OHMS transcript #{transcript_log_id}")
      end

      footnote_text
    end

    #private

    def sync_timecodes
      legacy_transcript.sync_timecodes
    end

    # * adds a timecode anchor if needed.
    # * Catches "speaker" notation and wraps in class.
    # * Makes sure there is whitespace at the end. Keep it all appropriately html safe.
    def format_ohms_line(line)
      ohms_line_str = line.text
      line_number = line.line_num

      # catch speaker prefix, adapted from standard PHP OHMS viewer
      if ohms_line_str =~ /\A[[:space:]]*([A-Z\-.\' ]+:) (.*)\Z/
        ohms_line_str = safe_join([
          content_tag("span", $1, class: "transcript-speaker"),
          " ",
          $2
        ])
      end

      # replace each footnote reference [[footnote]]12[[/footnote]] with proper HTML,
      # with a capture around the actual footnote number. eg `[[footnote]]3[[/footnote]]`
      footnote_reference_regexp = %r{\[\[footnote\]\] *(\d+?) *\[\[\/footnote\]\]}

      # ohms_line_str needs to be marked as html_safe, as it contains intended HTML,
      # and already was -- but the gsub will remove the html_safe marker.
      # We have hopefully taken care of HTML escaping safety ourselves!
      ohms_line_str = ohms_line_str.gsub(footnote_reference_regexp) do |match_to_replace|
        # have to re-match to get footnote number out, becuase of
        # weirdness with gsub block form, sorry.
        footnote_number = match_to_replace.match(footnote_reference_regexp)[1]
        render OralHistory::FootnoteReferenceComponent.new(
          footnote_text: footnote_text_for(footnote_number),
          number: footnote_number,
          show_dom_id: is_first_reference?(footnote_number)
        )
      end.html_safe

      # If there are any timecodes associated with#
      # this line, pick one to show.
      ts = timecode_content_tag_for_line(line_number)

      # add em together with whitespace on end either way
      safe_join([ts, ohms_line_str, " \n"])
    end


    # If there is a timestamp for this line, return its content_tag.
    # Otherwise, just a blank string.
    def timecode_content_tag_for_line(line_number)
      tc = timecode_for_line(line_number)
      return '' unless tc
      content_tag(
        "a",
        format_ohms_timestamp(tc[:seconds]),
        href: "#t=#{tc[:seconds]}",
        class: "ohms-transcript-timestamp",
        data: { "ohms_timestamp_s" => tc[:seconds]}
      )
    end

    # The OHMS editor allows us to associate one timecode per word.
    # Our display, however, really only accomodates the display of one
    # of these on the left of each line. This method picks at most one
    # from the array of timecodes at sync_timecodes[line_number].
    def timecode_for_line(line_number)

      # Look up the timecodes for this line.
      # They have already been processed in ohms_xml.rb
      # to remove consecutive timecodes. In most cases,
      # there will be either zero or one timecode in
      # array timecodes_for_line.
      timecodes_for_line = sync_timecodes[line_number]

      # If this is the first line, try adding a zero timestamp
      # to the first word.
      if line_number == 1
        timecodes_for_line = add_zero_timecode(timecodes_for_line)
      end

      # Finally, just return the first timecode
      # associated with the line.
      timecodes_for_line.present? ? timecodes_for_line[0] : nil
    end

    # The first line is special: we want to add an
    # extra "zero-second" timestamp to it -- as long as
    # the first word doesn't already have
    # a timestamp associated with it.
    def add_zero_timecode(timecodes_for_first_line)
      zero_timecode = [{:word_number=>1, :seconds=>0}]
      return zero_timecode if timecodes_for_first_line.blank?
      first_word_is_free = (timecodes_for_first_line.none? { |k| k[:word_number] == 1 })
      if first_word_is_free
        return zero_timecode + timecodes_for_first_line
      end
      # Otherwise just leave it as is.
      timecodes_for_first_line
    end

    # To prevent duplicate html ids, only output one html ID for
    # each footnote reference. If there are several references to a footnote,
    # only the first gets an html ID.
    def is_first_reference?(ref_number)
      already_been_output = @references_already_output.include?(ref_number)
      @references_already_output << ref_number
      !already_been_output
    end
  end
end
