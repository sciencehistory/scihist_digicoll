class GoogleArtsAndCultureDownloadCreatorJob < ApplicationJob

  def perform(user: user, start_date: nil, end_date: nil)
    begin
      logger.info("#{self.class}: Starting download for #{work.title}.")

      #Unless dates are provided (no, you can't pass in a scope) we just use all works in the user's cart
      scope = user.works_in_cart
      files_to_close = []
      tmp_zipfile = Tempfile.new(["files", ".zip"]).tap { |t| t.binmode }
      exporter = GoogleArtsAndCulture::Exporter.new(scope)
      Zip::File.open(tmp_zipfile.path, create: true) do |zipfile|

        metadata_csv_tempfile = exporter.metadata_csv_tempfile
        entry = ::Zip::Entry.new(zipfile.name, 'metadata.csv', compression_method: ::Zip::Entry::STORED)
        zipfile.add(entry, metadata_csv_tempfile)
        files_to_close << metadata_csv_tempfile

        exporter.file_hash.each do |file_name, uploaded_file_obj|
          downloaded_file = uploaded_file_obj.download
          entry = ::Zip::Entry.new(zipfile.name, file_name, compression_method: ::Zip::Entry::STORED)
          zipfile.add(entry, downloaded_file)
          files_to_close << downloaded_file
          # TODO: update the download object with number of items added
        end
      end
      tmp_zipfile.close
      download = user.google_arts_and_culture_downloads.create!
      download.put_file(tmp_zipfile)
      download.status = "success"
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
