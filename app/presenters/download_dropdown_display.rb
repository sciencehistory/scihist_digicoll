# Renders the download button with a dropdown menu of options.
#
# The standard menu also includes "rights" information, to put that next to
# the downloads.
#
#     DownloadDropdownDisplay.new(asset).display
#
#     # Don't know if it's a work or an asset?
#     DownloadDropdownDisplay.new(member.leaf_representative).display
#
# This component also has other methods meant as public API, if you need
# the download options but want to render them in other ways (TODO).
#
#
# ## Preloading required
#
# Uses leaf_representative and it's derivatives, as well as #parent.
# So these should be pre-loaded with Rails eager-loading if you're going to be displaying a bunch of these,
# as you usually are.
class DownloadDropdownDisplay < ViewModel
  valid_model_type_names "Asset"

  alias_method :asset, :model

  def display
    content_tag("div", class: "action-item downloads dropup") do
      button +
      content_tag("div", class: "dropdown-menu download-menu", "aria-labelledby" => menu_button_id) do
        menu_items
      end
    end
  end

  private

  def asset_download_options
    @asset_download_options ||= DownloadOptions::ImageDownloadOptions.new(asset).options
  end

  def parent
    asset.parent
  end

  def menu_button_id
    # include our object_id just to ensure uniqueness
    "dropdownMenu_downloads_#{asset.friendlier_id}_#{self.object_id}"
  end


  def button
    content_tag("button",
                "<i class='fa fa-download' aria-hidden='true'></i> Download".html_safe,
                type: "button",
                class: "btn btn-primary dropdown-toggle",
                id: menu_button_id,
                "data-toggle" => "dropdown",
                "aria-haspopup" => "true",
                "aria-expanded" => "false")
  end

  # Returns a string of rendered menu items
  def menu_items
    elements = []

    if parent && parent.rights.present?
      elements << "<h3 class='dropdown-header'>Rights</h3>".html_safe
      elements << rights_statement_item
      elements << "<li class='dropdown-divider'></li>".html_safe
    end

    if asset_download_options
      elements << "<h3 class='dropdown-header'>Download selected image</h3>".html_safe
      asset_download_options.each do |download_option|
        elements << format_download_option(download_option)
      end
    end

    safe_join(elements)
  end

  def format_download_option(download_option)
    label = safe_join([download_option.label, content_tag("small", download_option.subhead)])
    content_tag("a", label, class: "dropdown-item", href: download_option.url)
  end

  def rights_statement_item
    RightsIconDisplay.new(parent, mode: :dropdown_item).display
  end

end
