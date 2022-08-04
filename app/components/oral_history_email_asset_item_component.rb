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

  # returns hash of label => url
  #
  # A download link, for FLAC files with both FLAC and M4A variants
  def additional_links
    @additional_links ||= begin
      links = {}

      main_link_label = ScihistDigicoll::Util.humanized_content_type(main_file.content_type)
      main_link_label << " - " + ScihistDigicoll::Util.simple_bytes_to_human_string(main_file.size)

      links[main_link_label] =
        shrine_file_url(shrine_file: main_file, disposition: "attachment", filename: item_filename)

      if flac_with_m4a?
        # add the original flac link too
        links["FLAC - #{ScihistDigicoll::Util.simple_bytes_to_human_string(asset.size)}"] =
          shrine_file_url(shrine_file: asset.file,
                          disposition: "attachment",
                          filename: DownloadFilenameHelper.filename_for_asset(asset))
      end

      links
    end
  end

  def item_label
    "#{item_filename} - #{ScihistDigicoll::Util.humanized_content_type(main_file.content_type)}"
  end

  def item_filename
    @item_filename ||= DownloadFilenameHelper.filename_for_asset(asset, derivative_key: (:m4a if flac_with_m4a?))
  end

  def item_url
    shrine_file_url(shrine_file: main_file, disposition: "inline", filename: item_filename)
  end

  def shrine_file_url(shrine_file: main_file, disposition: "inline", filename:)
    shrine_file.url(
      public: false,
      expires_in: OralHistoryDeliveryMailer::ASSET_EXPIRATION_TIME,
      response_content_type: shrine_file.content_type,
      response_content_disposition: ContentDisposition.format(
        disposition: disposition,
        filename: filename
      )
    )
  end
end
