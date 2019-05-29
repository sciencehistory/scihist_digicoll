require 'rails_autolink'
# Takes a description string (from a work.description) and formats it for display.
# Ported from chf-sufia/app/helpers/description_formatter_helper.rb

# DescriptionDisplayFormatter.new(work.description).format
# DescriptionDisplayFormatter.new(work.description, truncate:true).format

class DescriptionDisplayFormatter

  def initialize(description, truncate: false)
    @description = description
    # truncate: true is used in _index_result.html.erb .
    @truncate = truncate ? true : false
  end

  def format
    sanitize
    truncate_description if @truncate
    add_line_breaks
    turn_bare_urls_into_links
    @description.html_safe
  end

  private

  # Sanitize the HTML. Should have been sanitized on input, but just to be safe.
  def sanitize
     @description = DescriptionSanitizer.new.sanitize(@description)
  end

  # Truncate, if requested.
  def truncate_description
    @description = HtmlAwareTruncation.truncate_html(@description, length: 220, separator: /\s/)
  end

  # Convert line breaks to paragraphs.
  def add_line_breaks
    @description = ActionController::Base.helpers.simple_format(@description, {}, sanitize: false)
  end

  # Create links out of bare URLs, and add external-link icons to them.
  # Leave untouched any link *tags* entered in description field.
  # This is an artifact of
  # a) the way things worked *before* link tags were allowed in the Sufia description field
  # b) obsolete communications guidelines.
  #
  # We may later decide to overhaul the content such that
  # the content contains no bare links.
  def turn_bare_urls_into_links
    icon = '<i class="fa fa-external-link" aria-hidden="true"></i>'
    @description = ActionController::Base.helpers.auto_link(@description, sanitize: false) do |text|
      "#{icon}#{('&nbsp;' + text)}"
    end
  end

end # class