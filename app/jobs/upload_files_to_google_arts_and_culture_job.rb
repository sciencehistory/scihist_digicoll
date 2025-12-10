# app/jobs/upload_work_to_google_arts_and_culture_job.rb

class UploadFilesToGoogleArtsAndCultureJob  < ApplicationJob

  def perform(work:,  attribute_keys:, column_counts: )

    downloaded_files = []
    @work = work
    @attribute_keys = attribute_keys
    @column_counts = column_counts
    
    files = GoogleArtsAndCulture::WorkSerializer.new(@work, attribute_keys: @attribute_keys, column_counts: column_counts).files.to_h

    bucket = google_arts_and_storage_bucket

    files.each do |filename, uploaded_file_obj|
      file_obj = uploaded_file_obj.download
      downloaded_files << file_obj
      begin
        #file = bucket.create_file(file_obj.path, filename)
        #puts "Uploaded #{filename} to gs://#{bucket_name}/#{filename}"
        puts "Done with #{filename}"
      rescue Google::Apis::ClientError, Google::Cloud::PermissionDeniedError => e
        puts "Unable to open the bucket: #{e.message}"
      end
    end
  ensure
    (downloaded_files || []).each do |tmp_file|
      tmp_file.close
      tmp_file.unlink
    end
  end

  def google_arts_and_storage_bucket
    google_arts_and_storage_bucket ||= begin
      credentials_json_string = ScihistDigicoll::Env.lookup(:google_arts_and_culture_credentials)
      bucket_name =             ScihistDigicoll::Env.lookup(:google_arts_and_culture_bucket_name)
      project_id =              ScihistDigicoll::Env.lookup(:google_arts_and_culture_project_id)


      credentials = ::Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: StringIO.new(credentials_json_string),
        scope: "https://www.googleapis.com/auth/devstorage.read_write"
      )
      storage = Google::Cloud::Storage.new( project_id: project_id, credentials: credentials)

      begin
        bucket = storage.bucket(bucket_name)
      rescue Google::Apis::ClientError, Google::Cloud::PermissionDeniedError => e
        puts "Unable to open the bucket: #{e.message}"
      end
      
      if bucket.nil?
        puts "Error: Bucket '#{bucket_name}' not found or inaccessible."
      end

      bucket
    end
  end
end
