# frozen_string_literal: true

class RightsIconComponent < ApplicationComponent
    attr_reader :mode, :work, :rights_term

  def initialize(work:, mode: :large)
    raise ArgumentError.new("mode must be :large or :dropdown_item") unless [:large, :dropdown_item].include?(mode)

    @work = work
    @mode = mode
    @rights_term = work.rights && RightsTerm.find(work.rights)
  end

  def call
    return "" unless has_rights_statement?

    if mode == :large
      display_large
    else
      display_dropdown_item
    end
  end

  # one line, all a link
  def display_dropdown_item
    # since we're using short label, the icon needs an alt tag if appropriate to explain the icon.

    link_to(rights_url, target: "_blank", class: ['rights-statement', mode.to_s.dasherize, layout_class]) do
      image_tag(rights_category_icon_src, class: "rights-statement-logo", alt: rights_term.icon_alt) +
      " ".html_safe +
      content_tag("span",
                  (rights_term.short_label_inline || "").html_safe,
                  class: "rights-statement-label")
    end
  end

  # a sort of logotype lock-up, with an internal link, so we can put a "rel: license" on it for CC.
  def display_large
    content_tag("div", class: ['rights-statement', mode.to_s.dasherize, layout_class]) do
      large_graphical_element +
      " ".html_safe +
      content_tag("span", rights_icon_label, class: "rights-statement-label")
    end
  end

  private

  # our CSS does different things for rightsstatement-style and creative_commons style, we want to
  # give it a class so we can.
  def layout_class
    rights_category == "creative_commons" ? "creative-commons-org" : "rights-statements-org"
  end

  def has_rights_statement?
    work.rights.present?
  end

  # We use URLs as our values in Work#rights
  def rights_url
    work.rights
  end

  # HTML label (becuase it includes a <br> at the right point) for the rights statement,
  # from our local metadata, adapted from rightstatements.org
  def rights_icon_label
    if rights_category == "creative_commons"
      # special long form
      "This work is licensed under a ".html_safe + link_to(rights_term.label + ".", rights_url, target: "_blank", rel: "license")
    else
      link_to((rights_term.short_label_html || "").html_safe, rights_url, target: "_blank")
    end
  end

  def large_graphical_element
    # creative commons can show multiple "bubble" icons, they don't need alt text
    # becuase we display a complete textual label next to it.
    if rights_category == "creative_commons"
      images =  [image_tag(rights_category_icon_src, class: "rights-statement-logo", alt: "")]

      (rights_term.pictographs || []).each do |pictograph_image|
        images << image_tag("cc_pictographs/#{pictograph_image}", class: "rights-statement-logo", alt: "")
      end

      link_to rights_url, target: "_blank", alt: rights_term.label, title: rights_term.label do
        safe_join images
      end
    else
      # just the category icon, it does need alt text because we just display a short label
      # next to it, which doesn't include what the icon conveys.
      image_tag(rights_category_icon_src, class: "rights-statement-logo", alt: rights_term.icon_alt)
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
