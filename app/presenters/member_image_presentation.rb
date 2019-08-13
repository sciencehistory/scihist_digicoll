# A thumb, usually with 'view' and 'download' buttons below it. We call that the "member image" presentation.
# Naming is hard!
#
# (Descended from app/views/curation_concerns/base/_show_page_image.html.erb in chf_sufia)
#
# Could be a child work, could be an Asset. If it's a child work, it doesn't get view/download buttons,
# but instead gets an "Info" button linking to child work. (That is just a legacy decision cause it was
# easier to implement -- for child work that has _multiple_ Assets attached to it, unclear what a good UX
# is. It could be changed later.)
#
# The MemberImage can actually be of mutiple sizes, the large poster size for the "hero" section
# of page (pass in `size: :large`, :large size thumb will be used), or the more standard size (`size: :standard`,
# standard thumb, default).
#
# And can also be lazy-loading or not.
#
# You pass in a Work or Asset -- a direct member, not a leaf_representative.
#
# Note that we will need to access the leaf_representative and it's
# derivatives, so if displaying a list of multiple (as you usually will be), you should
# eager load these, possibly with kithe `with_representative_derivatives` scope. You DO NOT
# pass in the leaf_representative itself, pass in the member -- we need to know about it
# to know what to display.
#
# ## Access Control
#
# This component WILL refuse to show something the user does not have permission to see,
# as a fail-safe guard. It will just show our placeholder image in that case.
#
# In general, we intend the front-end to NOT try to put these on the page at all,
# we don't want to show people the placeholder, this is just a fail-safe to avoid
# showing non-public content in case of other errors.
class MemberImagePresentation < ViewModel
  valid_model_type_names "Work", "Asset", "NilClass"

  alias_method :member, :model
  attr_reader :size, :lazy

  def initialize(member, size: :standard, lazy: false)
    @lazy = !!lazy
    @size = size
    super(member)
  end

  def display
    if member.nil? || representative_asset.nil? || !user_has_access_to_asset?
      return not_available_placeholder
    end

    content_tag("div", class: "member-image-presentation") do
      content_tag("div", class: "thumb") do
        content_tag("a", href: view_href, data: view_data_attributes) do
          ThumbDisplay.new(representative_asset, thumb_size: size, lazy: lazy).display
        end
      end +
      content_tag("div", class: "action-item-bar") do
        action_buttons_display
      end
    end
  end

  private

  def user_has_access_to_asset?
    can?(:read, representative_asset)
  end

  def not_available_placeholder
    content_tag("div", class: "member-image-presentation") do
      content_tag("div", class: "thumb") do
        tag "img", alt: "", src: asset_path("placeholderbox.svg"), width: "100%", class: "not-available-placeholder";
      end
    end
  end

  def representative_asset
    member.leaf_representative
  end

  # All action buttons should be wrapped in a div.action-item, to make CSS
  # work right.
  #
  # For legacy reasons, cow paths arrived at in chf_sufia, there's a kind of weird logic
  # for what buttons to show.
  #
  # For a direct asset, we show both download and view buttons in LARGE view, else
  # just download.
  #
  # For a child work, in LARGE view we show THREE buttons: download, view and info (link to child).
  # Otherwise, non-large, just "info" button.
  def action_buttons_display
    if member.kind_of?(Work)
      if size == :large
        download_button + view_button + info_button
      else
        info_button
      end
    else
      if size == :large
        download_button + view_button
      else
        download_button
      end
    end
  end

  def download_button
    DownloadDropdownDisplay.new(member.leaf_representative, display_parent_work: member.parent).display
  end

  def view_button
    content_tag("div", class: "action-item view") do
      content_tag("a",
        href: view_href,
        class: "btn btn-primary",
        data: view_data_attributes) do
          "<i class='fa fa-search' aria-hidden='true'></i> View".html_safe
      end
    end
  end

  # When viewer, useful for right-click open in another tab, and we
  # set to anchor link to open viewer.
  #
  # For non-images with no viewer, simply link to original.
  def view_href
    if member.leaf_representative&.content_type&.start_with?("image/")
      viewer_path(member.parent.friendlier_id, member.friendlier_id)
    else # PDF, etc, just try to show it in the browser
      download_path(member.leaf_representative, disposition: :inline)
    end
  end

  # to trigger image viewer
  def view_data_attributes
    if member.leaf_representative&.content_type&.start_with?("image/")
      {
        trigger: "scihist_image_viewer",
        member_id: member.friendlier_id
      }
    else
      {}
    end
  end

  # For a child work only, 'info' button links to public work view page
  def info_button
    return "" unless member.kind_of?(Work)

    content_tag("div", class: "action-item info") do
      link_to "Info", work_path(member), class: "btn btn-primary"
    end
  end

end
