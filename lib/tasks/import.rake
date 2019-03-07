namespace :scihist_digicoll do
  desc """Import all JSON import files present in `#{Rails.root}/tmp/import`.
  To generate the JSON import files, see instructions in lib/tasks/export.rake
  in project https://github.com/sciencehistory/chf-sufia/.
  The export files will be created within that project's tmp/export .
  Move them to a corresponding tmp/import file in this project,
  and finally, run `bundle exec rake scihist_digicoll:import`.

  If you know the credentials for your Fedora server,
  you can get access to protected items as well. Use ENV variables
  to provide them to this Rake task. Here's an example:

  export FEDORA_USERNAME='joe'
  export FEDORA_PASSWORD='shmo'
  export RAILS_ENV='production'
  chown -R digcol:deploy /opt/scihist_digicoll/current/tmp/import
  cd /opt/scihist_digicoll/current/
  bundle exec rake scihist_digicoll:import

  Note: this import will DELETE AND OVERWRITE Works and Collections
  in scihist_digicoll that have the same friendlier_id.

  However, if an existing Asset a) has the same friendlier_id and b)
  contains an identical file (as indicated by the sha1 hash), we
  consider it hasn't changed, and leave it alone.
  """

  task :import => :environment do
    # Some options. If this were a CLI thing, we could have better CLI ui.
    disable_bytestream_import = ENV['DISABLE_BYTESTREAM_IMPORT'] == "true"

    import_dir = Rails.root.join('tmp', 'import')
    fileset_dir = Dir[import_dir.join("filesets").join("*.json")]
    work_dir = Dir[import_dir.join("genericworks").join("*.json")]
    collection_dir = Dir[import_dir.join("collections").join("*.json")]

    # Import all the Assets, then all the Works,
    # and finally all the Collections.

    #Total number of tasks: ingest each file
    # and then do post-processing for each of the 3 file types.

    total_tasks = fileset_dir.count
    # Generic works increment the progress bar twice.
    total_tasks += work_dir.count * 2
    total_tasks += collection_dir.count

    if total_tasks == 0
      abort ("No files found to import in #{import_dir}")
    end
    progress_bar = ProgressBar.create(total: total_tasks, format: "%a %t: |%B| %R/s %c/%u %p%% %e")


    progress_bar.log("INFO: Importing FileSets")
    fileset_dir.each do |path|
      Importers::FileSetImporter.new(
        JSON.parse(File.read(path)),
        progress_bar,
        disable_bytestream_import: disable_bytestream_import).save_item
    end

    progress_bar.log("INFO: Importing Genericworks")
    work_dir.each do |path|
      Importers::GenericWorkImporter.new(JSON.parse(File.read(path)), progress_bar).save_item
    end

    progress_bar.log("INFO: Setting GenericWork and Asset relationships")
    work_dir.each do |path|
      Importers::RelationshipImporter.new(JSON.parse(File.read(path))).import
      progress_bar.increment
    end

    progress_bar.log("INFO: Importing Collections")
    collection_dir.each do |path|
      Importers::CollectionImporter.new(JSON.parse(File.read(path)), progress_bar).save_item
    end
  end

  task :import_one => :environment do
    import_dir = Rails.root.join('tmp', 'import')
    progress_bar = ProgressBar.create(total: 1, format: "%a %t: |%B| %R/s %c/%u %p%% %e")
    %w(FileSet GenericWork Collection).each do |s|
      importer_class = "Importers::#{s}Importer".constantize
      importer_class.file_paths.each do |path|
        next unless path.include? ENV['THE_ITEM']
        importer = importer_class.new(path, progress_bar)
        importer.save_item()
      end
    end # exporters.each
    puts 'WARNING: This is just for testing. Please run a full import to reconnect this item to its containers / containees.'
  end

  task :audit_import => :environment do
    import_dir = Rails.root.join('tmp', 'import')
    fileset_dir = Dir[import_dir.join("filesets").join("*.json")]
    work_dir = Dir[import_dir.join("genericworks").join("*.json")]
    collection_dir = Dir[import_dir.join("collections").join("*.json")]


    total_tasks = fileset_dir.count
    total_tasks += work_dir.count
    total_tasks += collection_dir.count
    progress_bar = ProgressBar.create(total: total_tasks, format: "%a %t: |%B| %R/s %c/%u %p%% %e")

    report_file = File.new("tmp/audit_report.txt", "w")


    progress_bar.log("INFO: Auditing FileSet => Asset")
    fileset_dir.each do |path|
      Importers::FileSetAuditor.new(JSON.parse(File.read(path)), report_file).check_item
      progress_bar.increment
    end

    progress_bar.log("INFO: Auditing GenericWork => Work")
    work_dir.each do |path|
      Importers::GenericWorkAuditor.new(JSON.parse(File.read(path)), report_file).check_item
      progress_bar.increment
    end

    progress_bar.log("INFO: Auditing Collection")
    collection_dir.each do |path|
      Importers::CollectionAuditor.new(JSON.parse(File.read(path)), report_file).check_item
      progress_bar.increment
    end

    report_file.close

    errors = File.readlines(report_file.path)
    if errors.empty?
      puts "\n\nNo problems found\n\n"
    else
      puts "\n\nAudit problems:\n\n"
      puts errors
    end
    File.unlink(report_file.path)
  end # task
end # namespace
