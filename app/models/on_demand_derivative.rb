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
class OnDemandDerivative < ApplicationRecord
  def self.derivative_type_definitions
    {
      pdf_file: {
        suffix: "pdf",
        content_type: "application/pdf"
      },
      zip_file: {
        suffix: "zip",
        content_type: "application/zip"
      }
    }
  end

  SHRINE_STORAGE_KEY = :on_demand_derivatives

  # Still in progress, and hasn't been touched in this long? Give up and restart
  STALE_IN_PROGRESS_SECONDS = 20.minutes
  # Error happened this long ago? Willing to try again.
  ERROR_RETRY_SECONDS = 10.minutes

  PRESIGNED_URL_EXPIRES_IN = 2.days

  enum deriv_type: self.derivative_type_definitions.keys.collect {|v| [v.to_s, v.to_s]}.to_h.freeze,
       status: %w{in_progress success error}.collect {|v| [v, v]}.to_h.freeze


  belongs_to :work

  def deriv_type_definition
    self.class.derivative_type_definitions[deriv_type.to_sym]
  end

  # What is our expected filename/path/key in storage? Based on inputs_checksum so unique
  # location if inputs_checksum changes.
  def file_key
    "#{work.friendlier_id}/#{deriv_type}_#{inputs_checksum}.#{deriv_type_definition[:suffix]}"
  end

  def uploaded_file
    @uploaded_file ||= Shrine::UploadedFile.new(
      "id" => file_key,
      "storage" => SHRINE_STORAGE_KEY,
      "metadata" => {
        "mime_type" => deriv_type_definition[:content_type]
      }
    )
  end

  def file_exists?
    uploaded_file.exists?
  end

  def file_url
    uploaded_file.url(
      public: false,
      expires_in: PRESIGNED_URL_EXPIRES_IN
      #response_content_disposition: "adf"
    )
  end

  def put_file(io)
    Shrine.storages[SHRINE_STORAGE_KEY].upload(io, file_key)
  end


end
