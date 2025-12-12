
class UploadFilesToGoogleArtsAndCultureJob  < ApplicationJob
  def perform(work_ids:)
    downloaded_files = []
    @work_ids = work_ids
    bucket = google_arts_and_storage_bucket

    work_ids.each do |id|
      work = Work.find(id)
      file_hash = GoogleArtsAndCulture::WorkSerializer.file_hash(work)
      file_hash.each do |filename, uploaded_file_obj|
        file_obj = uploaded_file_obj.download
        downloaded_files << file_obj
        begin
          unless bucket.nil?
            file = bucket.create_file(file_obj.path, filename)
            puts "Uploaded #{filename} to gs://#{bucket_name}/#{filename}"
          end
          puts "Done with #{filename}"
        rescue Google::Apis::ClientError, Google::Cloud::PermissionDeniedError => e
          puts "Unable to open the bucket: #{e.message}"
        ensure
          (downloaded_files || []).each do |tmp_file|
            tmp_file.close
            tmp_file.unlink
          end
        end
      end
    end
  end

  def google_arts_and_storage_bucket
    google_arts_and_storage_bucket ||= begin

      credentials_json_string = ScihistDigicoll::Env.lookup(:google_arts_and_culture_credentials)
      credentials_io =          StringIO.new(credentials_json_string)
      bucket_name =             ScihistDigicoll::Env.lookup(:google_arts_and_culture_bucket_name)
      project_id =              ScihistDigicoll::Env.lookup(:google_arts_and_culture_project_id)
      auth_scope =              "https://www.googleapis.com/auth/devstorage.read_write"

      credentials = ::Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: credentials_io,
        scope: auth_scope
      )
      storage = Google::Cloud::Storage.new( project_id: project_id, credentials: credentials)

      begin
        bucket = storage.bucket(bucket_name)
      rescue Google::Apis::ClientError, Google::Cloud::PermissionDeniedError => e
        puts "Unable to open bucket '#{bucket_name}' : #{e.message}"
      end
      
      bucket
    end
  end
end
