class FileListItemDisplay < ViewModel
  valid_model_type_names "Asset", "Work"

  alias_method :member, :model

  attr_reader :index, :view_link_attributes, :download_original_only

  # @param index [integer] Need index so we know whether to lazy-load
  #
  # @param view_link_attributes [Hash] extra attributes to add to title/thumb links
  #   to item. Used for adding 'data' attributes for analytics to our oral history
  #   PDF views.
  #
  # @param download_original_only [Boolean] default false. If true, instead of the
  #   download menu component in the action column, there will be a single download
  #   button to download original.
  def initialize(member, index:, view_link_attributes: {}, download_original_only: false)
    super(member)
    @index = index
    @view_link_attributes = view_link_attributes
    @download_original_only = download_original_only

    unless member.association(:parent).loaded?
      raise ArgumentError.new("parent must be pre-loaded to avoid n+1 queries please, on: #{member}")
    end
  end

  def display
    render "/presenters/file_list_item_display", member: member, view: self
  end


  # use label supplied by "role" if present, otherwise just the asset.title
  # as usual.
  def member_label
    @member_label ||= if member.role.present?
      t(member.role, scope: "asset_role_label", default: member.role.humanize )
    else
      member.title
    end
  end


  # Should we link thumbnail and title to a "view" link?
  #
  # Only for PDFs at present, but can expand later. We don't want to do
  # this for images, not sure about other stuff.
  #
  # As we are just linking to our download link with disposition inline,
  # for PDFs this will be displayed by the browser (for browsers capable of doing
  # so, which is all popular ones)
  #
  # If it's an image type, we're not really planning on using it with this component,
  # and don't know what to do with it,  here (we're not supporting the Viewer here
  # at present), so just punt and don't make it a link.
  #
  # This method is called with a block for the actual contents of the <a> tag, we use
  # it on template to wrap an image or a title string.
  #
  #     <%= decorator.link_to_non_audio_member(member) do %>
  #        contents of link
  #     <% end %>
  def maybe_view_link_to(member)
    if member.kind_of?(Asset) && member.content_type&.start_with?("image/")
      yield
    else
      link_to(download_path(member.leaf_representative, disposition: :inline), view_link_attributes) do
        yield
      end
    end
  end

  # Some metadata about asset, that we will display under the asset.
  def asset_details(asset)
    details = []

    if asset.content_type.present?
      details << ScihistDigicoll::Util.humanized_content_type(asset.content_type)
    end
    if asset.size.present?
      details << ScihistDigicoll::Util.simple_bytes_to_human_string(asset.size)
    end

    str = details.join(" — ")

    if asset.original_filename != member_label
      str = safe_join([str, "<br>".html_safe, asset.original_filename])
    end

    str
  end

  # Info button for Work.
  #
  # For Asset, if we have download_original_only it's a simple download link,
  # otherwise use download dropdown menu.
  def action_link
    if member.kind_of?(Work)
      link_to "Info", work_path(member), class: "btn btn-primary"
    elsif download_original_only
      link_to "Download", download_path(member), class: "btn btn-primary", data: {
        "analytics-category" => "Work",
        "analytics-action" => "download_original",
        "analytics-label"  => member.parent.friendlier_id
      }
    else
      DownloadDropdownDisplay.new(member, display_parent_work: member.parent, use_link:true).display
    end
  end
end
