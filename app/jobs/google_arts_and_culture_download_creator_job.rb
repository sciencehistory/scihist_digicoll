class GoogleArtsAndCultureDownloadCreatorJob < ApplicationJob


  # Requests all files needed for a google arts and culture export,
  # downloads them, compresses them, and adds them to a bucket on s3.
  def perform(user: user, user_notes: nil)
    @user = user
    @user_notes = user_notes
    return if @user.works_in_cart == []  || exporter.scope.count == 0
    begin
      logger.info("#{self.class}: Preparing download for #{@user.name}.")
      add_metadata_and_files_to_zip
      upload_to_s3
    rescue StandardError => e
      download.log_error(e)
      raise
    end
  ensure
     files_to_close.compact.each { |f| f.close; f.unlink }
  end


  # Adds all the necessary files to tmp_zipfile
  def add_metadata_and_files_to_zip
    Zip::File.open(tmp_zipfile.path, create: true) do |zipfile|
      add_to_zip_file(name:'metadata.csv', file_to_add: exporter.metadata_csv_tempfile, destination_zipfile: zipfile)
      exporter.file_hash.each do |name, uploaded_file_obj|
        add_to_zip_file(name:name, file_to_add: uploaded_file_obj.download, destination_zipfile: zipfile)
        download.log_work_added!
      end
    end
    tmp_zipfile.close
  end


  def files_to_close
    @files_to_close ||= []
  end

  # Create or return an object that preserves a record of this download.
  def download
    @download ||= @user.google_arts_and_culture_downloads.create!({
      user_notes: @user_notes,
      progress: 0,
      progress_total: exporter.file_hash.count
    })
  end

  def upload_to_s3
    File.open(tmp_zipfile.path, "r") { |io| download.put_file io }
    @download.update!({status: 'success'})
  end

  def tmp_zipfile
    @tmp_zipfile ||= Tempfile.new(["files", ".zip"]).tap { |t| t.binmode }
  end

  def exporter
    @exporter ||= GoogleArtsAndCulture::Exporter.new(scope)
  end

  def scope
    @scope = @user.works_in_cart
  end

  def add_to_zip_file(name:, file_to_add:, destination_zipfile:)
    entry = ::Zip::Entry.new(destination_zipfile.name, name, compression_method: ::Zip::Entry::STORED)
    destination_zipfile.add(entry, file_to_add)
    files_to_close << file_to_add
  end
end
