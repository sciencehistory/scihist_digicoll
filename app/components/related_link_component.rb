# Displays a single RelatedLink model on a Work or Collection show page, as a category prefix header, and link.
class RelatedLinkComponent < ApplicationComponent
  attr_reader :related_link

  # special labels if category.humanize isn't good enough.
  # can replace this with i18n or something if we want
  DISPLAY_LABELS = {
    "institute_biography" => "Historical biography",
    "institute_libguide" => "Library Guide",
    "other_external" => "Link",
    "other_internal" => "Link"
  }.freeze

  # @param related_link [RelatedLink]
  def initialize(related_link:)
    @related_link = related_link
  end

  def link_category_display
    DISPLAY_LABELS[related_link.category] || related_link.category.humanize
  end

  def should_show_link_domain?
    related_link.category == "other_external" && related_link.label.present? && link_domain.present?
  end

  def link_domain
    return @link_domain if defined?(@link_domain)

    @link_domain = begin
      URI.parse(related_link.url).host
    rescue URI::InvalidURIError
      nil
    end
  end
end
