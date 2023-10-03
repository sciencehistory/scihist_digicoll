class Asset < Kithe::Asset
  include AttrJson::Record::QueryScopes

  include RecordPublishedAt

  # keep json_attributes out of string version of model shown in logs and console --
  # because it's huge, and mostly duplicated by individual attributes that will be included!
  #
  # But we'll also keep out some enormous individual attributes, like :hocr
  self.filter_attributes = [:json_attributes, :derived_metadata_jsonb, :hocr]

  # We set an indexer to turn on Kithe Solr auto-indexing... but
  # we later override #update_index to index the PARENT WORK when
  # we ourselves change -- we don't index Assets, but we do include
  # some asset content in Works, so may need to re-index them.
  if ScihistDigicoll::Env.lookup(:solr_indexing) == 'true'
    self.kithe_indexable_mapper = Work.kithe_indexable_mapper
  end

  has_many :fixity_checks, foreign_key: "asset_id", inverse_of: "asset", dependent: :destroy

  # dependent is intentionally nil, to leave asset_id in the status record for
  # logging purposes.
  has_many :active_encode_statuses, foreign_key: "asset_id", inverse_of: "asset", dependent: nil

  set_shrine_uploader(AssetUploader)

  # We are doing a weird thing with shrine making it use an attr_json attribute instead
  # of a db column. We 1) create the `attr_json`, then 2) in the shrine attachment we tell it
  # column_serializer:nil tells shrine not to serialize the JSON, let
  # attr_json take care of that.
  #
  # And ActiveModel::Type::Value.new tells attr_json to just pass it through without
  # transformation (it's sort of the basic no-op or null type), to get serialized to
  # json by parent column.
  attr_json :hls_playlist_file_data, ActiveModel::Type::Value.new
  include VideoHlsUploader::Attachment(:hls_playlist_file, store: :video_derivatives, column_serializer: nil)

  before_promotion :store_exiftool

  before_promotion :invalidate_corrupt_tiff, if: ->(asset) { asset.content_type == "image/tiff" }


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
  attr_json :derivative_storage_type, :string, default: "public"

  # alt_text was added for Oral Histories portraits and migrating existing data,
  # but can be used for any asset.
  attr_json :alt_text, :string

  # Caption also motivated by Oral Histories data migration, and is not
  # really anticipated for any other use.
  attr_json :caption, :string

  attr_json :transcription, :text
  attr_json :english_translation, :text

  # If this is set, do not create OCR for this asset,
  # regardless of the parent work's settings.
  attr_json :suppress_ocr, :boolean, default: false

  # A place for staff to enter any internal notes about OCR for this asset.
  attr_json :ocr_admin_note, :text

  # OCR data in hOCR format, for the image asset
  attr_json :hocr, :text, container_attribute: :derived_metadata_jsonb

  # holds a JSON-able Hash, exiftool json output
  attr_json :exiftool_result, ActiveModel::Type::Value.new, container_attribute: :derived_metadata_jsonb


  validates :ocr_admin_note,
    presence: { message: ": Please specify why OCR is suppressed." },
    if: Proc.new { |a| a.suppress_ocr }

  validates :derivative_storage_type, inclusion: { in: ["public", "restricted"] }

  DERIVATIVE_STORAGE_TYPE_LOCATIONS = {
    "public" => :kithe_derivatives,
    "restricted" => :restricted_kithe_derivatives
  }.freeze

  after_update_commit :ensure_correct_derivatives_storage_after_change
  after_destroy_commit :log_destroyed


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

  # our hls_playlist_file attachment is usually created by AWS MediaConvert,
  # then we want to save the location of the already existing file in the
  # shrine attachment.
  #
  # @param s3_url [String] `s3://` url that must reference a location
  #   in shrine :video_derivatives storage, or you'll get an ArgumentError
  #
  # @example
  #     asset.hls_playlist_file_as_s3 = "s3://scihist-digicoll-staging-derivatives-video/path/to/playlist.m3u8"
  #
  def hls_playlist_file_as_s3=(s3_url)
    storage = Shrine.storages[:video_derivatives]

    unless storage.respond_to?(:bucket)
      raise TypeError.new("this method is only intended for use with a :video_derivatives storage that is s3, but is #{storage.class}")
    end

    parsed = URI.parse(s3_url)

    unless parsed.scheme == "s3"
      raise ArgumentError.new("argument must be an s3:// url not #{s3_url}")
    end

    unless parsed.host == storage.bucket.name &&
        (storage.prefix.nil? || parsed.path.delete_prefix("/").start_with?(storage.prefix.to_s))
      expected_s3_prefix = File.join("s3://", storage.bucket.name, storage.prefix.to_s)
      raise ArgumentError.new("s3 url argument must be location in :video_derivatives storage at `#{expected_s3_prefix}`, not #{s3_url}")
    end

    id = parsed.path.delete_prefix("/")
    id = id.delete_prefix("#{storage.prefix.to_s}/") if storage.prefix

    # Use some a bit esoteric shrine API to set location directly,
    # triggering any necessary shrine lifecycle management (like deleting
    # old replaced file(s))
    hls_playlist_file_attacher.change(
      hls_playlist_file_attacher.uploaded_file(
        storage: :video_derivatives,
        id: id
      )
    )
  end

  # OVERRIDE of standard Kithe update index, to:
  #   * update PARENT in solr on change, we don't index Assets, but do index
  #     some aspects of assets in their parent Works.
  #   * and only when allow-listed attributes we know we index on parent have changed
  def update_index(mapper: kithe_indexable_mapper, writer:nil, **)
    if should_reindex_parent_after_save?
      # WEIRD workaround, in some cases the parent still this record in memory
      # even though it's been, and will use that in-memory list of members for
      # indexing in Solr! If that's going on, we need to make sure to reset
      # the association.
      if self.destroyed? && parent.members.loaded? && parent.members.include?(self)
        parent.members.reset
      end

      RecordIndexUpdater.new(parent, mapper: mapper, writer: writer).update_index
    end
  end

  # parent indexes attributes_of_interest from it's *published* child assets.
  #
  # We could reindex parent on ANY save of child... but can we do better,
  # and only reindex if we actually need to?
  #
  # If we have a parent, figure out if our attributes of interest have changed
  # in a way that that would effect parent indexing. Kind of tricky.
  #
  # It's better if we err on the side of indexing when we don't really need to,
  # worse if we end up not indexing when we do!
  #
  # This may be "too clever"... but seems ok?
  def should_reindex_parent_after_save?(indexed_attributes: [:transcription, :english_translation])
    if parent.nil?
      return false
    elsif self.destroyed?
      # if we were destroyed with indexed_attributes present, parent needs to be re-indexed
      # to remove us from index.
      indexed_attributes.any? { |attr| self.send(attr).present? }
    elsif self.saved_change_to_published?
      # if published status changed, we have to reindex if and only if we HAVE any indexed attributes,
      # to include them in index.
      indexed_attributes.any? { |attr| self.send(attr).present? }
    else
      # an ordinary save (including create), did any attributes of interest CHANGE? (Including removal)
      # then we need to reindex parent to get them updated in index.
      indexed_attributes.any? { |attr| self.saved_change_to_attribute(attr).present? }
    end
  end

  after_promotion DziFiles::ActiveRecordCallbacks, if: ->(asset) { asset.content_type&.start_with?("image/") && asset.derivative_storage_type == "public" }

  after_promotion :create_initial_checksum

  after_promotion :create_hls_video, if: ->(asset) { asset.content_type&.start_with?("video/") }

  after_commit DziFiles::ActiveRecordCallbacks, only: [:update, :destroy]

  # for ones we're importing from our ingest bucket via :remote_url, we want
  # to schedule a future deletion from ingest bucket.
  around_promotion :schedule_ingest_bucket_deletion, if: ->(asset) { asset.file.storage_key == :remote_url }

  # major category of our file type, used in routing to put the file category in URL
  # @returns String image, audio, video, pdf, etc.
  def file_category
    if content_type == "application/pdf"
      "pdf"
    else
      # audio, video, image, hypothetically could be "application" for something
      # we're not expecting, no big deal. "unk" for unknown if we don't have
      # a content-type

      primary, secondary = (content_type || "").split("/")
      return "unk" unless primary.present? && secondary.present?

      primary.downcase
    end
  end

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

  # Create an initial checksum for the item.
  # Ensures the file saved to s3 storage is identical
  # to the one characterized at ingest.
  def create_initial_checksum
    SingleAssetCheckerJob.perform_later(self)
  end

  def create_hls_video
    raise TypeError.new("can't be done for non-videos") unless content_type.start_with?("video/")

    # respect kithe backgrounding directives for derivatives to control how/whether
    # we do HLS derivatives too. Adapted from kithe on ordinary derivatives:
    # https://github.com/sciencehistory/kithe/blob/a8f76a3bb732823ff3e9b48e30ca9caa2f342e50/app/models/kithe/asset.rb#L168-L175
    Kithe::TimingPromotionDirective.new(key: :create_derivatives, directives: file_attacher.promotion_directives) do |directive|
      if directive.inline?
        CreateHlsVideoJob.perform_now(self)
      elsif directive.background?
        CreateHlsVideoJob.perform_later(self)
      end
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

  def log_destroyed
    info = {
      pk: self.id,
      friendlier_id: self.friendlier_id,
      original_filename: self.original_filename,
      created_at: self.created_at&.iso8601,
      location: self.file&.url(public: true)
    }
    if self.parent
      info.merge!(
        parent_friendlier_id: self.parent.friendlier_id,
        parent_class: self.parent.class.name,
        parent_title: "'#{self.parent.title}'"
      )
    end

    info_str = info.collect { |k, v| "#{k}=#{v}" }.join(" ")

    Rails.logger.info("Asset Destroyed: #{info_str}")
  end

  def store_exiftool
    Shrine.with_file(self.file) do |local_file|
      self.exiftool_result = Kithe::ExiftoolCharacterization.new.call(local_file.path)
    end
  end

  def invalidate_corrupt_tiff
    exif = Kithe::ExiftoolCharacterization.presenter_for(self.exiftool_result)

    # Catastrophic warnings from exiftool, this TIFF won't work
    # Actual errors encountered in actually encountered problem corrupt files
    fatal_errors = [
      /Missing required TIFF IFD0 .* StripOffsets/,
      /Missing required TIFF IFD0 .* RowsPerStrip/,
      /Missing required TIFF IFD0 .* StripByteCounts/,
      /Missing required TIFF IFD0 .* PhotometricInterpretation/,
      /Missing required TIFF IFD0 .* ImageWidth/,
      /Missing required TIFF IFD0 .* ImageHeight/,
      /Missing required TIFF ExifIFD .* ColorSpace/,
      /IFD0:StripOffsets is zero/,
      /IFD0:StripByteCounts is zero/,
      /Undersized IFD0 StripByteCounts/
    ].map { |error_regexp| exif.exiftool_validation_warnings.grep(error_regexp) }.flatten.uniq

    if fatal_errors.present?
      # We need to disable promotion, so that we can save our errors despite
      # the promotion cancellation without looping!
      original_promote = self.promotion_directives[:promote]
      self.set_promotion_directives(promote: false)

      self.file_attacher.add_metadata("ingest_validation_errors" => fatal_errors)

      self.set_promotion_directives(promote: original_promote)

      self.save!

      # ActiveRecord callback way of aborting chain...
      throw :abort
    end
  end
end
