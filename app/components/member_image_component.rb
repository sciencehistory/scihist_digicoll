# frozen_string_literal: true

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
# eager load these. You DO NOT
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
class MemberImageComponent < ApplicationComponent
  attr_reader :size, :lazy, :member, :image_label, :work_download_options, :containing_div_class

  delegate :can?, to: :helpers

  # just an easy place to DRY this, good enough for now
  # These are data-* attributes that will trigger the viewer to open.
  #
  # @param member_id friendlier_id for Asset/member for image to load, eg asset.friendlier_id
  # @param work_id: friendlier_id for actual containing work, eg `member.parent&.friendlier_id || representative_asset.friendlier_id`
  def self.viewer_trigger_data_attrs(member_id:, work_id:)
    {
        trigger: "scihist_image_viewer",
        member_id: member_id,
        analytics_category: "Work",
        analytics_action: "view",
        analytics_label: work_id
      }
  end

  # @param image_label [String] a very short label used for assistive technology
  #    in many of our actually existing cases we don't have more than "Image 10" to say.
  #    Will be used to construct labels like "View Image 10".  Will default to `alt_text` set on
  #    Asset, if present. Not actually necessarily suitable "alt" text, instead
  #    it's used to construct action labels like that!
  #
  #  @param work_download_options [Array<DownloadOption>] sometimes we want to show them, sometimes we
  #     don't, and they are expensive, so pass them in if you want them.
  def initialize(member, size: :standard, lazy: false, image_label: nil, work_download_options: nil, containing_div_class: nil )
    @lazy = !!lazy
    @size = size
    @member = member
    @containing_div_class = containing_div_class

    @image_label = image_label
    @work_download_options = work_download_options
  end

  def call
    if containing_div_class.present?
      content_tag("div", class: containing_div_class) do
        main_content
      end
    else # used for the hero image
      main_content
    end
  end



  private

  def main_content
    if member.nil? || representative_asset.nil? || !user_has_access_to_asset?
        return not_available_placeholder
      end

      content_tag("div", class: "member-image-presentation") do
        private_label +
        content_tag("a", **thumb_link_attributes) do
          render ThumbComponent.new(representative_asset, thumb_size: size, lazy: lazy, alt_text_override: "")
        end +

        content_tag("div", class: "action-item-bar") do
          action_buttons_display
        end
      end
  end

  # Link around big poster image, when we're in "large" size it duplicates
  # the "view" link, so should be hidden from accessible tech.
  # https://www.sarasoueidan.com/blog/keyboard-friendlier-article-listings/.
  #
  # When we're in "small" size, it needs appropriate aria-label
  def thumb_link_attributes
    thumb_link_attributes = {
      class: "thumb",
      href: view_href,
      data: view_data_attributes,
    }

    if size == :large
      thumb_link_attributes["tabindex"] = "-1"
      thumb_link_attributes["aria-hidden"] = "true"
    else
      thumb_link_attributes["aria-label"] = image_label ? "View #{image_label}" : "View"
    end

    thumb_link_attributes
  end

  def private_label
    return ''.html_safe if member.published?
    content_tag(:div, class: "private-badge-div") do
      content_tag(:span, title: "Private", class: "badge text-bg-warning") do
        "Private"
      end
    end
  end

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

  # use brand-main for large size thumb, otherwise brand-alt
  def btn_class_name
    @btn_class_name ||= (size == :large) ? "btn-brand-main" : "btn-brand-alt"
  end

  def download_button
    # We only include whole-work download menu section for large size, used as hero.
    render DownloadDropdownComponent.new(representative_asset,
                                          work_download_options: work_download_options,
                                          display_parent_work: member.parent,
                                          aria_label: ("Download #{image_label}" if image_label),
                                          btn_class_name: btn_class_name)
  end

  def view_button
    content_tag("div", class: "action-item view") do
      content_tag("a",
        href: view_href,
        class: "btn #{btn_class_name}",
        data: view_data_attributes) do
          "View".html_safe
      end
    end
  end

  # When viewer, useful for right-click open in another tab, and we
  # set to anchor link to open viewer.
  #
  # For non-images with no viewer, simply link to original.
  def view_href
    if member.parent && representative_asset&.content_type&.start_with?("image/")
      viewer_path(member.parent.friendlier_id, member.friendlier_id)
    else # PDF, etc, just try to show it in the browser
      download_path(representative_asset.file_category, representative_asset, disposition: :inline)
    end
  end

  # to trigger image viewer
  def view_data_attributes
    if representative_asset&.content_type&.start_with?("image/")
      self.class.viewer_trigger_data_attrs(
        member_id: member.friendlier_id,
        work_id: member.parent&.friendlier_id || representative_asset.friendlier_id
      )
    else
      {}
    end
  end

  # For a child work only, 'info' button links to public work view page
  def info_button
    return "" unless member.kind_of?(Work)

    content_tag("div", class: "action-item info") do
      link_to "Info", work_path(member), class: "btn #{btn_class_name}", "aria-label" => ("Info on #{member.title}" if member.is_a?(Work))
    end
  end

end
