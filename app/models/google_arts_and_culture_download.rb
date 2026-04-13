# Represents a zip file containing files and metadata meant to be downloaded from S3 and then exported into Google Arts and Culture.

class GoogleArtsAndCultureDownload < ApplicationRecord
  SHRINE_STORAGE_KEY = :google_arts_and_culture
  enum :status, %w{in_progress uploading success error}.collect {|v| [v, v]}.to_h.freeze
  belongs_to :user

  def works_added
    @works_added ||= 0
  end

  def log_work_added!
    @works_added = works_added + 1
    update!({progress: works_added})
  end

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
      response_content_type: 'application/zip',
      response_content_disposition: ContentDisposition.attachment(file_key)
    )
  end

  def put_file(io)
    update!({status: 'uploading'})
    begin
        Shrine.storages[SHRINE_STORAGE_KEY].upload(io, file_key)
    rescue => e
      log_error(e)
      raise
    end
  end

  def log_error(e)
    Rails.logger.info e.message
    update!({status: 'error', error_info: e.message})
  end
end