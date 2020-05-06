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

    content_tag("div", safe_join(paragraph_html_arr), class: "ohms-transcript-container")
  end

  def test_render
    render "works/ohms_footnote_reference"
  end


  # The HTML for the inline tooltip and footnote reference.
  def footnote_html(number)
    raw_footnote = model.footnote_array[number.to_i - 1]  || ''
    if raw_footnote == ''
      Rails.logger.warn("WARNING: Reference to empty or missing footnote #{number} for OHMS transcript #{model.accession}")
    end
    render "works/ohms_footnote_reference",
      footnote_text: raw_footnote.gsub('"', '&quot;'),
      number: number
  end

  private

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

    # deal with footnotes
    footnote_re = %r{\[\[footnote\]\](\d+)\[\[\/footnote\]\]}
    if footnote_match = ohms_line_str.match(footnote_re)
      replacement = footnote_html(footnote_match[1])
      ohms_line_str = ohms_line_str.sub(footnote_match[0], replacement).html_safe()
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