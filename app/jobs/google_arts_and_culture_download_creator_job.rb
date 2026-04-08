class GoogleArtsAndCultureDownloadCreatorJob < ApplicationJob

  def perform(user: user, user_notes: nil)
    begin
      logger.info("#{self.class}: Preparing download for #{user.name}.")

      scope = user.works_in_cart
      exporter = GoogleArtsAndCulture::Exporter.new(scope)

      work_count = exporter.scope.count
      raise StandardError, "No works in scope." unless work_count > 0
      files_to_close = []
      tmp_zipfile = Tempfile.new(["files", ".zip"]).tap { |t| t.binmode }
      download = user.google_arts_and_culture_downloads.create!
      download.update!({user_notes: user_notes, progress: 0, progress_total: exporter.file_hash.count })
      works_added = 0

      Zip::File.open(tmp_zipfile.path, create: true) do |zipfile|
        metadata_csv_tempfile = exporter.metadata_csv_tempfile
        entry = ::Zip::Entry.new(zipfile.name, 'metadata.csv', compression_method: ::Zip::Entry::STORED)
        zipfile.add(entry, metadata_csv_tempfile)
        files_to_close << metadata_csv_tempfile
        download.update!({progress: 0})
        exporter.file_hash.each do |file_name, uploaded_file_obj|
          downloaded_file = uploaded_file_obj.download
          entry = ::Zip::Entry.new(zipfile.name, file_name, compression_method: ::Zip::Entry::STORED)
          zipfile.add(entry, downloaded_file)
          files_to_close << downloaded_file

          works_added = works_added + 1
          download.update!({progress: works_added})
        end
      end

      tmp_zipfile.close

      download.update!({status: 'uploading'})

      File.open(tmp_zipfile.path, "r") do |io|
        download.put_file(io)
      end

      download.update!({status: 'success'})

      puts "File uploaded!"
      puts "File exists: #{download.file_exists?}"
      puts "File exists: #{download.uploaded_file}"
    rescue StandardError => e
      download.status = "error"
      download.error_info = e.message
      download.save!
      raise
    end
  ensure
     (files_to_close || []).compact.each do |f|
       f.close
       f.unlink
     end
  end #perform
end # class
