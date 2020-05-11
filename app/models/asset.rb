class Asset < Kithe::Asset
  has_many :fixity_checks, foreign_key: "asset_id", inverse_of: "asset", dependent: :destroy

  set_shrine_uploader(AssetUploader)

  THUMB_WIDTHS = AssetUploader::THUMB_WIDTHS

  IMAGE_DOWNLOAD_WIDTHS = AssetUploader::IMAGE_DOWNLOAD_WIDTHS


  # Our DziFiles object to manage associated DZI (deep zoom, for OpenSeadragon
  # panning/zooming) file(s).
  #
  #     asset.dzi_file.url # url to manifest file
  #     asset.dzi_file.exists?
  #     asset.dzi_file.create # normally handled by automatic lifecycle hooks
  #     asset.dzi_file.delete # normally handled by automatic lifecycle hooks
  def dzi_file
    @dzi_file ||= DziFiles.new(self)
  end

  after_promotion DziFiles::ActiveRecordCallbacks, if: ->(asset) { asset.content_type&.start_with?("image/") }
  after_commit DziFiles::ActiveRecordCallbacks, only: [:update, :destroy]
end
