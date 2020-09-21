class Asset < Kithe::Asset
  has_many :fixity_checks, foreign_key: "asset_id", inverse_of: "asset", dependent: :destroy

  set_shrine_uploader(AssetUploader)

  THUMB_WIDTHS = AssetUploader::THUMB_WIDTHS
  IMAGE_DOWNLOAD_WIDTHS = AssetUploader::IMAGE_DOWNLOAD_WIDTHS

  attr_json :admin_note, :text, array: true, default: -> { [] }

  # only used for oral histories, some assets marked non-published are still
  # available after request form, with or without medidation by human approval.
  attr_json :oh_available_by_request, :boolean

  # Most of our derivatives are kept in an S3 bucket with public access, even
  # when the asset is in a non-published state. But actual confidential material
  # that won't be published may need derivatives kept in a separate restricted access
  # bucket. Intended for non-published Oral History assets, eg "free access no internet release"
  #
  # Set rails_attribute true so we get rails dirty tracking.
  attr_json :derivative_storage_type, :string, default: "public", rails_attribute: true

  validates :derivative_storage_type, inclusion: { in: ["public", "restricted"] }

  DERIVATIVE_STORAGE_TYPE_LOCATIONS = {
    "public" => :kithe_derivatives,
    "restricted" => :restricted_kithe_derivatives
  }.freeze

  after_update_commit :ensure_correct_derivatives_storage_after_change

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

  after_promotion DziFiles::ActiveRecordCallbacks, if: ->(asset) { asset.content_type&.start_with?("image/") && asset.derivative_storage_type == "public" }
  after_commit DziFiles::ActiveRecordCallbacks, only: [:update, :destroy]


  # Ensure that recorded storage locations for all derivatives matches
  # current #derivative_storage_type setting.  Returns false only if
  # there are derivatives that exist, in wrong location.
  def derivatives_in_correct_storage_location?
    file_derivatives.blank? ||
      file_derivatives.values.collect(&:storage_key).all?(
        self.class::DERIVATIVE_STORAGE_TYPE_LOCATIONS.fetch(self.derivative_storage_type)
      )
  end

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

  # If derivative_storage_type changed in last save, fire off bg job
  # to move derivatives to correct place.
  def ensure_correct_derivatives_storage_after_change
    if derivative_storage_type_previously_changed? && file_derivatives.present?
      EnsureCorrectDerivativesStorageJob.perform_later(self)
    end
  end
end
