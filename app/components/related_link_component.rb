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

  def initialize(related_link:)
    @related_link = related_link
  end

  def link_category_display
    DISPLAY_LABELS[related_link.category] || related_link.category.humanize
  end
end
