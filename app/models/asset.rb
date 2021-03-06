class Asset < Kithe::Asset
  has_many :fixity_checks, foreign_key: "asset_id", inverse_of: "asset", dependent: :destroy

  set_shrine_uploader(AssetUploader)

  THUMB_WIDTHS = AssetUploader::THUMB_WIDTHS
  IMAGE_DOWNLOAD_WIDTHS = AssetUploader::IMAGE_DOWNLOAD_WIDTHS

  # The 'role' column says what role an asset plays in the work, for instance
  # the 'portrait' attached to an oral history. This is sort of an extension to PCDM,
  # it's still a member, but it has a role on the relationship too. Initially we
  # are using this so we can provide specialized interface for oral histories.
  enum role: %w{portrait transcript front_matter}.collect {|v| [v, v]}.to_h, _prefix: true

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

  # alt_text was added for Oral Histories portraits and migrating existing data,
  # but can be used for any asset.
  attr_json :alt_text, :string

  # Caption also motivated by Oral Histories data migration, and is not
  # really anticipated for any other use.
  attr_json :caption, :string

  attr_json :transcription, :text
  attr_json :english_translation, :text


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

  # for ones we're importing from our ingest bucket via :remote_url, we want
  # to schedule a future deletion from ingest bucket.
  around_promotion :schedule_ingest_bucket_deletion, if: ->(asset) { asset.file.storage_key == :remote_url }

  # Used as an around_promotion callback. If we're promoting a shrine cache file using remote_url storage, and
  # the file is from our ingest_bucket, then add a record to table to schedule it's deletion in the future
  # by an
  def schedule_ingest_bucket_deletion
    if self.file.storage_key == :remote_url && self.file.id.start_with?("https://#{ScihistDigicoll::Env.lookup(:ingest_bucket)}.s3.amazonaws.com")
      ingest_bucket_file_url = self.file.id
    end

    yield

    # schedule it for deletion if needed
    if ingest_bucket_file_url
      path = CGI.unescape(URI.parse(ingest_bucket_file_url).path.delete_prefix("/"))
      ScheduledIngestBucketDeletion.create!(path: path, asset: self, delete_after: Time.now + ScheduledIngestBucketDeletion::DELETE_AFTER_WINDOW)
    end
  end

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
