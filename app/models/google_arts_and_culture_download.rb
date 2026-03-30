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


  attr_reader :start_date, :end_date

  # def self.derivative_type_definitions
  #   {
  #     pdf_file: {
  #       suffix: "pdf",
  #       content_type: "application/pdf",
  #       creator_class_name: "WorkPdfCreator2"
  #     },
  #     zip_file: {
  #       suffix: "zip",
  #       content_type: "application/zip",
  #       creator_class_name: "WorkZipCreator"
  #     }
  #   }
  # end 

  # PRESIGNED_URL_EXPIRES_IN = 2.days.to_i

  #enum :deriv_type, self.derivative_type_definitions.keys.collect {|v| [v.to_s, v.to_s]}.to_h.freeze
  enum :status, %w{in_progress success error}.collect {|v| [v, v]}.to_h.freeze

  belongs_to :user #, inverse_of: google_arts_and_culture_downloads

  # def initialize(user)
  #   # unless OnDemandDerivative.derivative_type_definitions.keys.include?(derivative_type.to_sym)
  #   #   raise ArgumentError.new("unrecognized derivative type: #{derivative_type}")
  #   # end

  #   @user = user
  #   #@work = work
  #   #@derivative_type = derivative_type
  # end

  #def deriv_type_definition
  #  self.class.derivative_type_definitions[deriv_type.to_sym] || raise(ArgumentError.new("unrecognized derivative type: #{deriv_type}"))
  #end

  # What is our expected filename/path/key in storage? Based on inputs_checksum so unique
  # location if inputs_checksum changes.
  def file_key
    "google_arts_and_culture_downloads/google_arts_and_culture_downloads_#{id}.zip"
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
      expires_in: PRESIGNED_URL_EXPIRES_IN,
      response_content_type: uploaded_file.metadata["mime_type"],
      response_content_disposition: ContentDisposition.attachment(desired_filename)
    )
  end

  def put_file(io)
    Shrine.storages[SHRINE_STORAGE_KEY].upload(io, file_key)
  end

  protected

  def desired_filename
    parts = [
      DownloadFilenameHelper.first_three_words(work.title),
      work.friendlier_id,
      deriv_type
    ].collect(&:presence).compact

    Pathname.new(parts.join("_")).sub_ext(".#{deriv_type_definition[:suffix]}").to_s
  end
end
