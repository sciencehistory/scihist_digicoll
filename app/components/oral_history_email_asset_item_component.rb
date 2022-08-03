# A simple component that creates an individual "line" of asset delivery in
# the HTML emails delivered by OralHistoryDeliveryMailer
class OralHistoryEmailAssetItemComponent < ApplicationComponent
  attr_reader :asset

  def initialize(asset)
    @asset = asset
  end

  # the original file, but for FLAC we use the M4A deriv if we have it
  def main_file
    @main_file ||= if flac_with_m4a?
      asset.file_derivatives[:m4a] || asset.file
    else
      asset.file
    end
  end

  # a FLAC orig that has an M4A deriv available? We display differently.
  def flac_with_m4a?
    asset.content_type == "audio/flac" && asset.file_derivatives.has_key?(:m4a)
  end

  def item_label
    details = []
    details << ScihistDigicoll::Util.humanized_content_type(main_file.content_type) if main_file.content_type.present?
    details << ScihistDigicoll::Util.simple_bytes_to_human_string(main_file.size) if main_file.size.present?
    if details.present?
      "#{item_filename} (#{details.join(" — ")})"
    else
      item_filename
    end
  end

  def item_filename
    @item_filename ||= DownloadFilenameHelper.filename_for_asset(asset, derivative_key: (:m4a if flac_with_m4a?))
  end

  def item_url
    main_file.url(
      public: false,
      expires_in: OralHistoryDeliveryMailer::ASSET_EXPIRATION_TIME,
      response_content_type: main_file.content_type,
      response_content_disposition: ContentDisposition.format(
        disposition: "inline",
        filename: item_filename
      )
    )
  end
end
