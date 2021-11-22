# Json-compat hash serializer for info for the scihist_viewer
# Returned by an HTTP endpoint for viewer.
#
#     ViewerMemberInfoSerializer.new(work).as_hash
#
#
class ViewerMemberInfoSerializer
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::TextHelper

  THUMB_DERIVATIVE = :thumb_mini

  attr_reader :work, :current_user

  def initialize(work, current_user:nil)
    @work = work
    @current_user = current_user
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
        downloads: download_options(asset).as_json,
        transcription_html: member.respond_to?(:transcription) && member.transcription.present? && simple_format(member.transcription),
        english_translation_html: member.respond_to?(:english_translation) && member.english_translation.present? && simple_format(member.english_translation)
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
