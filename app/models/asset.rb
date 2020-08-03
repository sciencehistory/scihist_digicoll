class Asset < Kithe::Asset
  has_many :fixity_checks, foreign_key: "asset_id", inverse_of: "asset", dependent: :destroy

  set_shrine_uploader(AssetUploader)

  THUMB_WIDTHS = AssetUploader::THUMB_WIDTHS
  IMAGE_DOWNLOAD_WIDTHS = AssetUploader::IMAGE_DOWNLOAD_WIDTHS

  attr_json :admin_note, :text, array: true, default: -> { [] }


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

  # What is total number of derivatives referenced in our DB?
  #
  # Since they are now referenced as keys inside a JSON hash in Asset, it's a bit
  # tricky to count. We use some rough SQL to ask postgres how many keys there are in
  # `derivatives` hashes in `file_data` json hash in Assets.
  #
  # Seems to work. Might be a little bit expensive, does not use indexes and requires a complete
  # table scan, but pg exact counts actually always require a table scan, and at our present
  # scale this is still pretty quick.
  #
  # TODO: We should probably extract this to kithe.
  def self.all_derivative_count
    Kithe::Asset.connection.select_all(
      "select count(*) from (SELECT id, jsonb_object_keys(file_data -> 'derivatives') FROM kithe_models WHERE kithe_model_type = 2) AS asset_derivative_keys;"
    ).first["count"]
  end
end
