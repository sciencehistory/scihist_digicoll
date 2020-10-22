# Json-compat hash serializer for info for the scihist_viewer
# Returned by an HTTP endpoint for viewer.
#
#     ViewerMemberInfoSerializer.new(work).as_hash
#
#
# It's a view model to easily get route helpers.
class ViewerMemberInfoSerializer < ViewModel
  THUMB_DERIVATIVE = :thumb_mini

  attr_reader :work

  def initialize(work)
    @work = work
    super(work)
  end

  def as_hash
    included_members.enum_for(:each_with_index).collect do |member, i|
      asset = member.leaf_representative

      {
        index: i + 1,
        memberShouldShowInfo: member.kind_of?(Work),
        title: member.title,
        memberId: member.friendlier_id,
        memberShowUrl: (work_path(member) if member.kind_of?(Work)),
        tileSource: asset.dzi_file.url,
        # if tilesource DZI is unavailable, give them a more reasonable sized JPG
        fallbackTileSource: { type: "image", url: download_derivative_path(asset, :download_medium, disposition: "inline") },
        thumbAspectRatio: ("#{asset.width.to_f / asset.height}" if asset.width && asset.height),
        downloads: [{"url":"/downloads/6q182k19f/download_small","label":"Small JPG","subhead":"800 x 1222px — 142 KB","analyticsAction":"download_jpg_small"},{"url":"/downloads/6q182k19f/download_medium","label":"Medium JPG","subhead":"1200 x 1833px — 339 KB","analyticsAction":"download_jpg_medium"},{"url":"/downloads/6q182k19f/download_large","label":"Large JPG","subhead":"2880 x 4399px — 2.3 MB","analyticsAction":"download_jpg_large"},{"url":"/downloads/6q182k19f/download_full","label":"Full-sized JPG","subhead":"5751 x 8784px — 8.4 MB","analyticsAction":"download_jpg_full"},{"url":"/downloads/6q182k19f","label":"Original file","subhead":"TIFF — 5751 x 8784px — 145 MB","analyticsAction":"download_original"}]
      }.merge(thumb_src_attributes(asset))
    end
  end

  private

  def included_members
    @included_members ||= begin
      members = work.members.order(:position)
      members = members.where(published: true) if current_user.nil?
      members.includes(:leaf_representative).select do |member|
        member.leaf_representative &&
        member.leaf_representative.content_type&.start_with?("image/") &&
        member.leaf_representative.stored?
      end
    end
  end

  def download_options(asset)
    DownloadOptions::ImageDownloadOptions.new(asset).options
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
