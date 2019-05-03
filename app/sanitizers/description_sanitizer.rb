# Used for sanitizing user-entered descriptions to have only HTML tags
# we want to allow.
#
# Based on code in rails_html_sanitizer, which doesn't have as nice
# an API as we'd like, this is way weirder than expected!
#
# only allow good html tags, and good attributes on those tags --
# no do-it-yourself style or class etc.
#
# Changes windows \r\n newlines to just \n.
#
#     DescriptionSanitizer.new.sanitize(description)
class DescriptionSanitizer < Rails::Html::Sanitizer
  class_attribute :allowed_tags
  self.allowed_tags = %w{b i cite a}

  class_attribute :allowed_attributes
  self.allowed_attributes = %w{href}

  attr_reader :scrubber

  def initialize
    @scrubber = Rails::Html::PermitScrubber.new.tap do |scrubber|
      scrubber.tags = allowed_tags
      scrubber.attributes = allowed_attributes
    end
  end

  def sanitize(html, options = {})
    return unless html
    return html if html.empty?

    loofah_fragment = Loofah.fragment(html)
    loofah_fragment.scrub!(@scrubber)
    properly_encode(loofah_fragment, encoding: 'UTF-8').gsub(/\r\n?/, "\n")
  end
end
