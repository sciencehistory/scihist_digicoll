# Renders the download button with a dropdown menu of options.
#
# The standard menu also includes "rights" information, to put that next to
# the downloads.
#
#     DownloadDropdownComponent.new(asset, display_parent_work: work)
#
#     # Don't know if it's a work or an asset?
#     DownloadDropdownComponent.new(member.leaf_representative, display_parent_work: work)
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
#
# ## Viewer-template mode
#
# For use in the JS viewer modal template, we can produce a dropdown menu which has rights and whole-work
# download links, but doesn't have any asset-specific links. Instead having a <div data-slot="selected-downloads">
# for the JS to fill in.
#
#     DownloadDropdownComponent.new(nil, display_parent_work: work, viewer_template: true)
#
# (This is a bit hacky)
#
class DownloadDropdownComponent < ApplicationComponent
  attr_reader :display_parent_work, :asset, :aria_label, :btn_class_name


  # @param asset [Asset] asset to display download links for
  # @param display_parent_work [Work] the Work we are in the context of displaying, used
  #   to determine whole-work download links (zip or pdf of all images), will have it's
  #   `members` and their `leaf_representative`s accessed so should be pre-loaded if needed for performance.
  #
  #   We don't just get from asset.parent, because intervening child work hieararchy
  #   may make it complicated, we need to be told our display parent context.
  #
  #   display_parent_work is also used for determining "rights" statement.
  # @param use_link [Boolean], default false, if true will make the link that opens the menu an
  #   ordinary hyperlink, instead of a button (used on audio playlist).
  # @param aria_label [String] aria_label for the primary "Download" button, we
  #   use to make it more specific like "Download Image 1" to avoid tons of
  #   identical "Download" buttons on page.
  # @param btn_class_name [String] default "btn-brand-alt", but maybe you want "btn-brand-main".
  #   The specific btn theme added on to bootstrap `btn` that will be there anyway.
  def initialize(asset,
      display_parent_work:,
      use_link: false,
      viewer_template: false,
      aria_label: nil,
      btn_class_name: "btn-brand-alt")

    if viewer_template
      raise ArgumentError.new("asset must be nil if template_only") unless asset.nil?
    else
      raise ArgumentError.new("asset can't be nil if not template_only") if asset.nil?
    end

    @display_parent_work = display_parent_work
    @use_link = use_link
    @asset = asset
    @aria_label = aria_label
    @btn_class_name = btn_class_name
  end

  def call
    # https://getbootstrap.com/docs/4.0/components/dropdowns/
    # viewer-navbar-btn and btn-group necessary for it to style correctly when embedded in viewer. :(
    content_tag("div", class: "action-item viewer-navbar-btn btn-group downloads #{@use_link ? "dropdown" : "dropup"}") do
      link_or_button +
      content_tag("div", class: "dropdown-menu download-menu", "aria-labelledby" => menu_button_id) do
        menu_items
      end
    end
  end

  private

  def viewer_template_mode?
    asset.nil?
  end

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

  def menu_button_id
    # include our object_id just to ensure uniqueness
    unless viewer_template_mode?
      "dropdownMenu_downloads_#{asset.friendlier_id}_#{self.object_id}"
    else
      "dropdownMenu_downloads_template_#{display_parent_work.friendlier_id}"
    end
  end

  def link_or_button
    if @use_link
      # no fontawesome download icon in link mode
      content_tag("a",
        "Download",
        link_or_button_options
      )
    else
      content_tag("button",
        "Download".html_safe,
        link_or_button_options
      )
    end
  end

  def link_or_button_options
    # https://getbootstrap.com/docs/4.3/components/dropdowns/
    #
    # * We supply data-boundary "viewport"; without this, specifically on the
    # OH Audio page where download dropdown is near right side of screen,
    # popper was miscalculating boundaries and letting download menu go out of screen.
    #
    #   * I don't think it messes up any other cases, if it does, we'll have to
    #   solve some other way, by changing DOM/CSS to fix, or having this component
    #   take an arg as to data-boundary.

    options = {
      id: menu_button_id,
      "data-toggle" => "dropdown",
      "aria-haspopup" => "true",
      "aria-expanded" => "false",
      "data-boundary": "viewport"
    }

    if aria_label
      options["aria-label"] = aria_label
    end

    if @use_link
      options[:class] = "dropdown-toggle download-link"
      options[:role] = "button"
      options[:href] = "#"
    else
      options[:type]  = "button"
      if viewer_template_mode?
        options[:class] = "btn btn-emphasis btn-lg dropdown-toggle"
      else
        options[:class] = "btn #{btn_class_name} dropdown-toggle"
      end
    end
    options
  end

  # Returns a string of rendered menu items
  def menu_items
    elements = []

    if display_parent_work && display_parent_work.rights.present?
      elements << "<h3 class='dropdown-header'>Rights</h3>".html_safe
      elements << rights_statement_item
      elements << "<div class='dropdown-divider'></div>".html_safe
    end

    if has_work_download_options?
      elements << "<h3 class='dropdown-header'>Download all #{display_parent_work.member_count} images</h3>".html_safe
      whole_work_download_options.each do |download_option|
        elements << format_download_option(download_option)
      end
      elements << "<div class='dropdown-divider'></div>".html_safe
    end

    if viewer_template_mode?
      elements << "<h3 class='dropdown-header'>Download selected image</h3>".html_safe
      elements << '<div data-slot="selected-downloads"></div>'.html_safe
    elsif asset_download_options
      elements << "<h3 class='dropdown-header'>Download selected #{thing_name}</h3>".html_safe
      asset_download_options.each do |download_option|
        elements << format_download_option(download_option)
      end
    end

    safe_join(elements)
  end

  def format_download_option(download_option)
    label = safe_join([
      download_option.label, (content_tag("small", download_option.subhead) if download_option.subhead.present?)
    ])

    content_tag("a", label,
                      class: "dropdown-item",
                      href: download_option.url,
                      data: download_option.data_attrs)
  end

  def rights_statement_item
    render(RightsIconComponent.new(mode: :dropdown_item, rights_id: display_parent_work&.rights, work: display_parent_work))
  end

  # have a PUBLISHED parent work, with more than 1 child, and AT LEAST ONE of it's children are images,
  # provide multi-image downloads. These are the only whole-work-download options we provide at present.
  #
  # (Our current PDF and Zip creators only create for published items, they can't create
  # for non-published items. But we don't have an easy way to efficiently access
  # number of published child items, we just use the parent being unpublished as a proxy
  # for "not ready")
  #
  # NOTE: We had been checking to make sure ALL members were images, but that was FAR
  # too resource intensive, it destroyed ramelli. Checking just one is okay though.
  def has_work_download_options?
    display_parent_work &&
    display_parent_work.published? &&
    display_parent_work.member_count > 1 &&
    display_parent_work.member_content_types(mode: :query).all? {|t| t.start_with?("image/")}
  end

  def whole_work_download_options
    return [] unless has_work_download_options?

    [
      DownloadOption.for_on_demand_derivative(
        label: "PDF", derivative_type: "pdf_file", work_friendlier_id: @asset&.parent&.friendlier_id
      ),
      DownloadOption.for_on_demand_derivative(
        label: "ZIP", derivative_type: "zip_file", work_friendlier_id: @asset&.parent&.friendlier_id
      )
    ]
  end

end
