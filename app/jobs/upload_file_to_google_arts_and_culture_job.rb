# app/jobs/upload_work_to_google_arts_and_culture_job.rb

class UploadFileToGoogleArtsAndCultureJob < ApplicationJob
  def perform(filename:, file_obj:, bucket: )
    file = bucket.create_file(file_obj.path, filename)
    puts "Uploaded #{file.name} to gs://#{bucket_name}/#{filename}"
  rescue StandardError => e
    puts "An error occurred: #{e.message}"
  end
end
