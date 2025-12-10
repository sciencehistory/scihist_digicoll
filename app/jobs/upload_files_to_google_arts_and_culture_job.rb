# app/jobs/upload_work_to_google_arts_and_culture_job.rb


# Uploads all the files in a given work to Google Arts and Culture.

# Creates its own connection to Google Cloud Storage.


class UploadFilesToGoogleArtsAndCultureJob < ApplicationJob

  def perform(work:,  attribute_keys:, column_counts: )

    @work = work
    @attribute_keys = attribute_keys
    @column_counts = column_counts

    pp "MADE IT HEREeee"

    pp GoogleArtsAndCulture::WorkSerializer.new(@work, attribute_keys: @attribute_keys, column_counts: column_counts).files

    pp "gaot"

    files = GoogleArtsAndCulture::WorkSerializer.new(@work, attribute_keys: @attribute_keys, column_counts: column_counts).files.to_h
    puts "Files are:"
    pp files



    #file = bucket.create_file(file_obj.path, filename)
    puts "Uploaded #{file.name} to gs://#{bucket_name}/#{filename}"
  #rescue StandardError => e
  #  puts "An error occurred: #{e.message}"
  end


  def upload_files_to_google_arts_and_culture
    downloaded_files = []
    pp "goat"
    pp files

    files.each do |filename, uploaded_file_obj|
      file_obj = uploaded_file_obj.download
      downloaded_files << file_obj
      
      begin
        upload(
          filename: filename,
          file_obj: file_obj,
          bucket:   google_arts_and_storage_bucket
        )
        puts "added #{filename}"
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


  def upload(filename:, file_obj:, bucket: )
    file = bucket.create_file(file_obj.path, filename)
    puts "Uploaded #{file.name} to gs://#{bucket_name}/#{filename}"
  rescue StandardError => e
    puts "An error occurred: #{e.message}"
  end

end
