# Takes a description string (from a work.description) and formats it for display.
# Ported from chf-sufia/app/helpers/description_formatter_helper.rb
#
#     DescriptionDisplayFormatter.new(work.description).format
#     DescriptionDisplayFormatter.new(work.description, truncate:true).format
#
# Or for a plain-text description, with html tags stripped:
#     DescriptionDisplayFormatter.new(work.description, truncate:true).format_plain
#
class DescriptionDisplayFormatter
  # for simple_format and sanitize:
  include ActionView::Helpers::TextHelper

  DEFAULT_TRUNCATE = 220

  attr_reader :description

  # @param str [String] description string
  # @option truncate [Integer,Boolean] truncate string to this amount, or `true` for default 220. Default value is nil, for not truncate.
  def initialize(description, truncate: false)
    @description = description

    truncate = DEFAULT_TRUNCATE if truncate == true
    @truncate = truncate
  end



  def format
    return "".html_safe if description.blank?
    result = sanitize(description)

    if @truncate
      result = truncate_description(result)
    end
    result = add_line_breaks(result)
    result = turn_bare_urls_into_links(result)

    result.html_safe
  end

  # A plain-text (html tags removed) description that is also truncated to specified chars.
  #
  # We don't want it escaped here, cause it will be escaped appropriately as point of use (which might be in a URL
  # query param).  But also NOT marked html_safe, because it's not!
  #
  # The truncate helper makes that hard, we have to embed it in a string literal to get it neither
  # escaped nor marked html_safe
  def format_plain
    return "" if description.blank?

    str = strip_tags(description)

    # For our existing specs, don't want this to be html_safe?, which it becomes
    # in Rails 7-- to_str will make it non-html-safe again, for consistency, although
    # may not matter.
    str = str.to_str

    if @truncate
      str = "#{truncate(str, escape: false, length: @truncate, separator: /\s/)}"
    end

    return str
  end

  private

  # Sanitize the HTML. Should have been sanitized on input, but just to be safe.
  def sanitize(str)
     DescriptionSanitizer.new.sanitize(str)
  end

  # Truncate, if requested.
  def truncate_description(str)
    HtmlAwareTruncation.truncate_html(str, length: @truncate, separator: /\s/)
  end

  # Convert line breaks to paragraphs.
  def add_line_breaks(str)
    simple_format(str, {}, sanitize: false)
  end

  # Create links out of bare URLs, and add external-link icons to them.
  # Leave untouched any link *tags* entered in description field.
  # This is an artifact of
  # a) the way things worked *before* link tags were allowed in the Sufia description field
  # b) obsolete communications guidelines.
  #
  # We may later decide to overhaul the content such that
  # the content contains no bare links.
  def turn_bare_urls_into_links(str)
    Rinku.auto_link(str) do |text|
      "<i class=\"fa fa-external-link\" aria-hidden=\"true\"></i>&nbsp;#{text}"
    end
  end

end # class
