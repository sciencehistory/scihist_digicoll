require 'rails_autolink'
# Takes a description string (from a work.description) and formats it for display.
# Ported from chf-sufia/app/helpers/description_formatter_helper.rb

# DescriptionDisplayFormatter.new(work.description).format
# DescriptionDisplayFormatter.new(work.description, truncate:true).format

class DescriptionDisplayFormatter < ViewModel

  def initialize(model, options ={})
    # truncate: true is used in _index_result.html.erb .
    @truncate = !! options.delete(:truncate)

    super
  end

  alias_method :description, :model

  def format
    result = sanitize(description)
    if @truncate
      result = truncate_description(result)
    end
    result = add_line_breaks(result)
    result = turn_bare_urls_into_links(result)

    result.html_safe
  end

  private

  # Sanitize the HTML. Should have been sanitized on input, but just to be safe.
  def sanitize(str)
     DescriptionSanitizer.new.sanitize(str)
  end

  # Truncate, if requested.
  def truncate_description(str)
    HtmlAwareTruncation.truncate_html(str, length: 220, separator: /\s/)
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
    auto_link(str, sanitize: false) do |text|
      "<i class=\"fa fa-external-link\" aria-hidden=\"true\"></i>&nbsp;#{text}"
    end
  end

end # class