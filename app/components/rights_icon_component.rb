# frozen_string_literal: true
#
# Display a logo and text for a rights statement -- can display a large one, a one-line one for
# use in a menu, or just a link.
#
# Can also display for a "standard" one-icon rights statement OR a Creative Commons one
# that can have multiple CC bubbles, and requires a different layout.
#
# Having to handle so many cases which have ended up different visually have meant there are a LOT
# of weird conditionals in here, this should probably be refactored, into several different components
# with shared func located elsewhere.
class RightsIconComponent < ApplicationComponent
    attr_reader :mode, :rights_id, :rights_term, :work

  # @param rights_id [String] The `id` from RightsTerm.
  # @param mode [Symbol] :large, :dropdown_item, or :simple_link
  # @param work [Work] optional, mostly so we can link to a specific-work rights explanation page.
  #   if not present, work-specific link won't happen.

  def initialize(rights_id:, work:nil, mode: :large)
    raise ArgumentError.new("mode must be :large or :dropdown_item") unless [:large, :dropdown_item, :simple_link].include?(mode)

    @rights_id = rights_id
    @mode = mode
    @rights_term = RightsTerm.find(@rights_id) # rights_id can be nil, we'll get a null object term
    @work = work
  end

  def call
    return "" unless has_rights_statement?

    if mode == :large
      display_large
    elsif mode == :simple_link
      display_simple_link
    else
      display_dropdown_item
    end
  end

  # one line, all a link
  def display_dropdown_item
    # since we're using short label, the icon needs an alt tag if appropriate to explain the icon.

    link_to(rights_url, target: "_blank", class: ['rights-statement', mode.to_s.dasherize]) do
      image_tag(rights_category_icon_src, class: "rights-statement-logo", alt: rights_term.icon_alt) +
      " ".html_safe +
      content_tag("span",
                  (rights_term.short_label_inline || "").html_safe,
                  class: "rights-statement-label")
    end
  end

  def display_simple_link
    link_to(rights_term.label, rights_url, target: "_blank")
  end

  # a sort of logotype lock-up, with an internal link, so we can put a "rel: license" on it for CC.
  def display_large
    if rights_category == "creative_commons"
      content_tag("div", class: ['rights-statement', mode.to_s.dasherize, "creative-commons-org"]) do
        creative_commons_large_linked_icons +
        " ".html_safe +
        content_tag("span", creative_commons_rights_icon_label, class: "rights-statement-label")
      end
    else
      # The category icon, does need alt text because we just display a short label
      # next to it, which doesn't include what the icon conveys.
      content_tag("div", class: ['rights-statement', mode.to_s.dasherize, "rights-statements-org"]) do
        image_tag(rights_category_icon_src, class: "rights-statement-logo", alt: rights_term.icon_alt) +
        " ".html_safe +
        content_tag("span", rights_icon_label, class: "rights-statement-label")
      end
    end
  end

  private

  def has_rights_statement?
    rights_id.present?
  end

  # Do we want to display our custom local explanation page? Or just use the rights_id URL
  # We use URLs as our values in Work#rights
  def rights_url
    if rights_term.param_id.present?
      rights_term_path(rights_term.param_id, work&.friendlier_id)
    else
      rights_id
    end
  end

  def creative_commons_rights_icon_label
    "This work is licensed under a ".html_safe + link_to(rights_term.label + ".", rights_url, target: "_blank", rel: "license")
  end

  # HTML label (becuase it includes a <br> at the right point) for the rights statement,
  # from our local metadata, adapted from rightstatements.org
  def rights_icon_label
    link_to((rights_term.short_label_html || "").html_safe, rights_url, target: "_blank")
  end

  # creative commons can show multiple "bubble" icons, they don't need alt text
  # becuase we display a complete textual label next to it.
  def creative_commons_large_linked_icons
    images =  [image_tag(rights_category_icon_src, class: "rights-statement-logo", alt: "")]

    (rights_term.pictographs || []).each do |pictograph_image|
      images << image_tag("cc_pictographs/#{pictograph_image}", class: "rights-statement-logo", alt: "")
    end

    link_to rights_url, target: "_blank", alt: rights_term.label, title: rights_term.label do
      safe_join images
    end
  end

  def rights_category
    rights_term.category
  end

  # One of three SVG icons, depending on category, as recorded in our local list.
  def rights_category_icon_src
    case rights_category
      when "in_copyright"
        "rightsstatements-InC.Icon-Only.dark.svg"
      when "no_copyright"
        "rightsstatements-NoC.Icon-Only.dark.svg"
      when "creative_commons"
        "cc_pictographs/cc.svg"
      else
        "rightsstatements-Other.Icon-Only.dark.svg"
      end
  end


end
