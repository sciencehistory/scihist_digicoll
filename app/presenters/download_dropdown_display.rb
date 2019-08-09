# Renders the download button with a dropdown menu of options.
#
# The standard menu also includes "rights" information, to put that next to
# the downloads.
#
#     DownloadDropdownDisplay.new(asset, display_parent_work: work).display
#
#     # Don't know if it's a work or an asset?
#     DownloadDropdownDisplay.new(member.leaf_representative, display_parent_work: work).display
#
# This class uses other "DownloadOptions" classes to actually figure out the
# appropriate options for a given asset of given type and state, if you need
# that info directly to present in some other way, see those classes in
# app/presenters/download_options. (Right now the logic for picking _which_ one of
# those to use for a given asset is in here, but could be extracted out.)
#
# `display_parent_work` is used for determining any "whole-work" download options (zip or pdf
# of images), and will have it's `members` and their leaf_representatives accessed,
# so should have them pre-loaded to avoid n+1 queries if needed.
#
# ## Preloading required
#
# Uses leaf_representative and it's derivatives, as well as #parent.
# So these should be pre-loaded with Rails eager-loading if you're going to be displaying a bunch of these,
# as you usually are.
#
# Current code decides what options to display based on derivatives *actually existing*, to avoid
# providing an option that can't be delivered. That does mean it needs info from the db on what derivs
# exist though. (It also uses metadata on the existing deriv records to provide nice info on the dl
# link on file size/dimensions/etc.)
class DownloadDropdownDisplay < ViewModel
  valid_model_type_names "Asset"

  alias_method :asset, :model

  attr_reader :display_parent_work


  # @param asset [Asset] asset to display download links for
  # @param display_parent_work [Work] the Work we are in the context of displaying, used
  #   to determine whole-work download links (zip or pdf of all images), will have it's
  #   `members` and their `leaf_representative`s accessed so should be pre-loaded if needed for performance.
  #
  #   We don't just get from asset.parent, because intervening child work hieararchy
  #   may make it complicated, we need to be told our display parent context.
  def initialize(asset, display_parent_work:nil, use_link: false)
    @display_parent_work = display_parent_work
    @use_link = use_link
    super(asset)
  end

  def display
    content_tag("div", class: "action-item downloads dropup") do
      link_or_button +
      content_tag("div", class: "dropdown-menu download-menu", "aria-labelledby" => menu_button_id) do
        menu_items
      end
    end
  end

  private

  # What do we call it in labels to the user
  def thing_name
    if asset.nil? || asset.content_type.blank?
      "file"
    elsif asset.content_type.start_with?("image/")
      "image"
    elsif asset.content_type == "application/pdf"
      "document"
    else
      "file"
    end
  end

  def asset_download_options
    @asset_download_options ||= if asset&.content_type&.start_with?("audio/")
      DownloadOptions::AudioDownloadOptions.new(asset).options
    else
      DownloadOptions::ImageDownloadOptions.new(asset).options
   end
  end

  def parent
    asset.parent
  end

  def menu_button_id
    # include our object_id just to ensure uniqueness
    "dropdownMenu_downloads_#{asset.friendlier_id}_#{self.object_id}"
  end

  def link_or_button
    options = {
      id: menu_button_id, "data-toggle" => "dropdown",
      "aria-haspopup" => "true", "aria-expanded" => "false"
    }

    if @use_link
      options[:class] = "dropdown-toggle download-link"
    else
      options[:type]  = "button"
      options[:class] = "btn btn-primary dropdown-toggle"
    end

    content_tag(
      (@use_link ? "a" : "button"),
      "<i class='fa fa-download' aria-hidden='true'></i> Download".html_safe,
      options
    )
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

  def link
    content_tag("a",
                "<i class='fa fa-download' aria-hidden='true'></i> Download".html_safe,
                class: "dropdown-toggle download-link",
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
      elements << "<div class='dropdown-divider'></div>".html_safe
    end

    if has_work_download_options?
      elements << "<h3 class='dropdown-header'>Download all #{display_parent_work.members.length} images</h3>".html_safe

      elements << content_tag("a", "PDF", href: "#", class: "dropdown-item",
        data: {
          trigger: "on-demand-download",
          "work-id": display_parent_work.friendlier_id,
          "derivative-type": "pdf_file"
        }
      )

      elements << content_tag("a", href: "#", class: "dropdown-item",
        data: {
          trigger: "on-demand-download",
          "work-id": display_parent_work.friendlier_id,
          "derivative-type": "zip_file"
        }
      ) do
        "ZIP<small>of full-sized JPGs</small>".html_safe
      end

      elements << "<li class='dropdown-divider'></li>".html_safe
    end

    if asset_download_options
      elements << "<h3 class='dropdown-header'>Download selected #{thing_name}</h3>".html_safe
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

  # have a parent work, and all it's children are images, are the only whole-work
  # download options we offer at present.
  def has_work_download_options?
    display_parent_work &&
      display_parent_work.members.length > 1 &&
      display_parent_work.members.all? do |member|
        member.leaf_representative && member.leaf_representative.file_data && member.leaf_representative.content_type.start_with?("image/")
      end
  end

end
