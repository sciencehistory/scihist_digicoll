# Represents one of of our large whole-work derivatives (zip of images, or PDF of images),
# that are created on-demand.
#
# Represents the in_progress/success/error state of creation on demand.
#
# An OnDemandDerivative record may exist when the actual derivative no longer exists in storage,
# because we store them in an S3 with lifecycle rules set to remove not recently used copies,
# as a sort of cache.
#
# You can #put_file, #file_exists?, and #file_url to deal with the attached file. We use Shrine::UploadedFile
# objects directly, without using Shrine Attachment code.
class GoogleArtsAndCultureDownload < ApplicationRecord

  SHRINE_STORAGE_KEY = :google_arts_and_culture_storage

  attr_reader :start_date, :end_date, :status

  enum :status, %w{in_progress success error}.collect {|v| [v, v]}.to_h.freeze

  belongs_to :user #, inverse_of: google_arts_and_culture_downloads

  def file_key
    "google_arts_and_culture_downloads_#{id}.zip"
  end

  def uploaded_file
    @uploaded_file ||= Shrine::UploadedFile.new(
      "id" => file_key,
      "storage" => SHRINE_STORAGE_KEY,
      "metadata" => {
        "mime_type" => 'application/zip'
      }
    )
  end

  def file_exists?
    uploaded_file.exists?
  end

  def file_url
    uploaded_file.url(
      public: false,
      response_content_type: uploaded_file.metadata["mime_type"],
      response_content_disposition: ContentDisposition.attachment(desired_filename)
    )
  end

  def put_file(io)
    begin
        Shrine.storages[SHRINE_STORAGE_KEY].upload(io, file_key)
    rescue Aws::S3::MultipartUploadError => e
      Rails.logger.info e.message
      e.errors.each { |err| Rails.logger.info err.inspect }
      raise
    end
  end

  protected

  def desired_filename
    parts = [
      'google_arts_and_culture_',
      id
    ].collect(&:presence).compact

    Pathname.new(parts.join("_")).sub_ext(".zip").to_s
  end
end
