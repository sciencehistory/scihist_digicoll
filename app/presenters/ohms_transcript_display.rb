# Turn OHMS XML into HTML, using tags based on OHMS native viewer, at
# around OHMS version ~3.8.
#
# Includes timestamp tags at appropriate place, from <sync> data.
#
# Input is our OralHistoryContent::OhmsXml wrapper/helper object.
class OhmsTranscriptDisplay < ViewModel
  OHMS_NS = OralHistoryContent::OhmsXml::OHMS_NS

  valid_model_type_names "OralHistoryContent::OhmsXml"

  # Trying to display somewhat like OHMS does. We need to track lines separated by individual "\n", that
  # matches line count in `sync`. But we also need to group lines separated by "\n\n" into paragraphs.
  # "\n\n" does mean an empty line as far as line count.
  #
  # We're also doing things somewhat different than OHMS when we coudn't figure out why it made
  # any sense (like a bare span for an empty line, or using span as a wrapper for p which is
  # probably illegal HTML)
  #
  # This is kinda dense code, but it works, not sure it would be cleaner with an view template,
  # and should be more performant this way.
  def display
    paragraphs = []
    current_paragraph = []
    model.transcript_lines.each_with_index do |line, index|
      current_paragraph << { text: line, line_num: index + 1}

      if line.empty?
        paragraphs << current_paragraph
        current_paragraph = []
      end
    end
    paragraphs << current_paragraph

    paragraph_html_arr = paragraphs.collect do |p_arr|
      content_tag("p", class: "ohms-transcript-paragraph") do
        safe_join(p_arr.collect do |line|
          content_tag("span", format_ohms_line(line), class: "ohms-transcript-line", id: "ohms_line_#{line[:line_num]}")
        end)
      end
    end

    transcript_html = content_tag("div", safe_join(paragraph_html_arr), class: "ohms-transcript-container")

    if model.footnote_array.present?
      transcript_html << content_tag("div") do
        render '/presenters/ohms_footnotes_section',
          footnote_array: model.footnote_array
      end
    end

    transcript_html
  end

  # The HTML for the inline tooltip and footnote reference.
  # We use a template for this; even with dozens of footnotes,
  # it doesn't appear to slow down the page load significantly.
  def footnote_html(number)
    # OhmsXmlValidator is in charge of validating the footnotes at
    # upload time and rejecting ones that are invalid.
    # We can thus assume the footnotes are valid at display time;
    # if the array of footnotes doesn't contain a footnote for `number`,
    # we are *not* going to throw an error.
    footnote_text = model.footnote_array[number.to_i - 1]  || ''
    if footnote_text == ''
      Rails.logger.warn("WARNING: Reference to empty or missing footnote #{number} for OHMS transcript #{model.accession}")
    end
    render '/presenters/ohms_footnote_reference',
      footnote_text: footnote_text,
      number: number
  end

  #private

  def sync_timecodes
    model.sync_timecodes
  end

  # * adds a timecode anchor if needed.
  # * Catches "speaker" notation and wraps in class.
  # * Makes sure there is whitespace at the end. Keep it all appropriately html safe.
  def format_ohms_line(line)
    ohms_line_str = line[:text]

    # catch speaker prefix
    if ohms_line_str =~ /\A([A-Z]+:) (.*)\Z/
      ohms_line_str = safe_join([
        content_tag("span", $1, class: "ohms-speaker"),
        " ",
        $2
      ])
    end

    # replace each footnote reference [[footnote]]12[[/footnote]] with proper HTML

    # Use this to scan the line for any footnotes (there can be more than 1)
    scan_line_for_footnotes_re =  %r{\[\[footnote\]\] *\d+? *\[\[\/footnote\]\]}
    # Use this to separate out the actual footnote number
    footnote_number_re = %r{\[\[footnote\]\] *(\d+?) *\[\[\/footnote\]\]}

    ohms_line_str.scan(scan_line_for_footnotes_re).each do |match_to_replace|
      footnote_number = match_to_replace.match(footnote_number_re)[1]
      replacement = footnote_html(footnote_number)
      # ohms_line_str needs to be marked as html_safe, as it contains HTML chars.
      ohms_line_str = ohms_line_str.sub(match_to_replace, replacement).html_safe()
    end

    # possibly we need sync anchor html
    sync_html = ""

    if line[:line_num] == 1
      # give a 0 timecode
      sync_html = content_tag("a", format_ohms_timestamp(0), href: "#", class: "ohms-transcript-timestamp", data: { "ohms_timestamp_s" => 0})
    elsif sync = sync_timecodes[line[:line_num]]
      sync_html = content_tag("a", format_ohms_timestamp(sync[:seconds]), href: "#", class: "ohms-transcript-timestamp", data: { "ohms_timestamp_s" => sync[:seconds]})
    end

    # add em together with whitespace on end either way
    safe_join([sync_html, ohms_line_str, " \n"])
  end

end
