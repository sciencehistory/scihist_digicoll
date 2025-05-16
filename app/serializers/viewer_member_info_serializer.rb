# Json-compat hash serializer for info for the scihist_viewer
# Returned by an HTTP endpoint for viewer.
#
#     ViewerMemberInfoSerializer.new(work).as_hash
#
#
class ViewerMemberInfoSerializer
  include Rails.application.routes.url_helpers

  THUMB_DERIVATIVE = :thumb_mini

  attr_reader :work, :show_unpublished

  def initialize(work, show_unpublished: false)
    @work = work
    @show_unpublished = show_unpublished
  end

  def as_hash
    included_members.enum_for(:each_with_index).collect do |member, i|
      asset = member.leaf_representative

      {
        index: i + 1,
        memberShouldShowInfo: member.kind_of?(Work),
        title: member.title,
        memberId: member.friendlier_id,
        whiteEdge: asset.file_metadata[AssetUploader::WHITE_EDGE_DETECT_KEY].presence,
        memberShowUrl: (work_path(member) if member.kind_of?(Work)),
        tileSource: asset.dzi_package.url,
        # if tilesource DZI is unavailable, give them a more reasonable sized JPG
        fallbackTileSource: { type: "image", url: download_derivative_path(asset, :download_medium, disposition: "inline") },
        thumbAspectRatio: ("#{asset.width.to_f / asset.height}" if asset.width && asset.height),
        downloads: download_options(asset).as_json
      }.merge(thumb_src_attributes(asset)).compact
    end
  end

  private

  def included_members
    @included_members ||= begin
      members = work.members.order(:position).strict_loading
      members = members.where(published: true) unless show_unpublished
      members.includes(:leaf_representative => :parent).select do |member|
        member.leaf_representative &&
        member.leaf_representative.content_type&.start_with?("image/") &&
        member.leaf_representative.stored?
      end
    end
  end

  def download_options(asset)
    # include the PDF link here if we only have one image, as there won't be a
    # fixed whole-work download section, but we still want it.
    ( work.member_count == 1 ? WorkDownloadOptionsCreator.new(work).options : []) + DownloadOptions::ImageDownloadOptions.new(asset).options
  end

  def thumb_src_attributes(asset)
    derivative_1x_url = asset.file_url(THUMB_DERIVATIVE)
    derivative_2x_url = asset.file_url("#{THUMB_DERIVATIVE.to_s}_2X")
    {
      thumbSrc: derivative_1x_url,
      thumbSrcset: "#{derivative_1x_url} 1x, #{derivative_2x_url} 2x"
    }
  end


end
