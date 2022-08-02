# A simple component that creates an individual "line" of asset delivery in
# the HTML emails delivered by OralHistoryDeliveryMailer
class OralHistoryEmailAssetItemComponent < ApplicationComponent
  attr_reader :asset

  def initialize(asset)
    @asset = asset
  end

  def download_label
    details = []
    details << ScihistDigicoll::Util.humanized_content_type(asset.content_type) if asset.content_type.present?
    details << ScihistDigicoll::Util.simple_bytes_to_human_string(asset.size) if asset.size.present?
    if details.present?
      "#{asset.title} (#{details.join(" — ")})"
    else
      asset.title
    end
  end

  def download_url
    asset.file.url(
      public: false,
      expires_in: OralHistoryDeliveryMailer::ASSET_EXPIRATION_TIME,
      response_content_type: asset.content_type,
      response_content_disposition: ContentDisposition.format(
        disposition: "inline",
        filename: DownloadFilenameHelper.filename_for_asset(asset)
      )
    )
  end
end
