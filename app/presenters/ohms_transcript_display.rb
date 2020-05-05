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

  # Show all the footnotes at the bottom of the text.
  # Might move this to the template.
  def display_footnotes
    array_of_divs = model.footnote_array.each_with_index.map do |footnote_text, i|
      footnote_number = i + 1
      (
        "<div class=\"footnote-page-bottom-container\">" +
          # An anchor so we can come down to the footnote section from the reference:
          "<a name=\"footnote#{footnote_number}\" id=\"footnote#{footnote_number}\"></a>" +
          # and a link so we can head back up to the reference:
          "<a data-role=\"footnote-page-bottom\" data-footnote-index=\"#{footnote_number}\" href=\"#\" >" +
          "#{footnote_number}.</a> #{footnote_text}" +
        "</div>"
      ).html_safe()
    end
    safe_join(array_of_divs)
  end

  private

  # The HTML for the inline tooltip and footnote reference.
  # Hovering over it will show the tooltip; clicking on it will take you to the
  # corresponding footnote at the bottom of the page.
  #
  # This is loosely based on:
  # http://hiphoff.com/creating-hover-over-footnotes-with-bootstrap/
  def footnote_html(number)
    # The text of the footnote. Escaped, as it'll be between quotes.
    footnote_text = (model.footnote_array[number.to_i - 1]).gsub('"', '&quot;')

    # Used to tie the footnote text with its number via aria-describedby.
    screenreader_only_id = "footnote-text-#{number}"

    # # First, an anchor, so we can link back to this footnote:
    the_html =  "<a name=\"footnote-reference#{number}\" id=\"footnote-reference#{number}\" ></a>" +
      # Then, a screenreader-only footnote:
      "<span class=\"sr-only\" id=\"#{screenreader_only_id}\" >#{number}. #{footnote_text}</span>" +
      #
      # Then, the actual tooltip (hidden until hover; not visible to mobile or screenreader users).
      "<span class=\"footnote\" aria-hidden=\"true\" data-toggle=\"tooltip\" title=\"#{footnote_text}\">" +
          # The actual footnote link:
          "<a aria-describedby=\"#{screenreader_only_id}\" data-role=\"footnote-reference\" data-footnote-index=\"#{number}\" href=\"#\">" +
            "[#{number}]" +
          "</a>" +
      "</span>"
    the_html.html_safe()
  end


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
