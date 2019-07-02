# Large-ish rights statement icon and text link, used on work show page.
class RightsIconDisplay < ViewModel
  valid_model_type_names "Work"

  alias_method :work, :model

  def display
    return "" unless has_rights_statement?

    link_to(rights_url, target: "_blank", class: 'rights-statement large') do
      image_tag(rights_icon, class: "rights-statement-logo") +
      content_tag("span", rights_icon_label, class: "rights-statement-label")
    end
  end

  private

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
    (RightsTerms.short_label_html_for(work.rights) || "").html_safe
  end

  # One of three SVG icons, depending on category, as recorded in our local list.
  def rights_icon
    case RightsTerms.category_for(work.rights)
      when "in_copyright"
        "rightsstatements-InC.Icon-Only.dark.svg"
      when "no_copyright"
        "rightsstatements-NoC.Icon-Only.dark.svg"
      else
        "rightsstatements-Other.Icon-Only.dark.svg"
      end
  end

end
