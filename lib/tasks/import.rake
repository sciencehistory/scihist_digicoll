namespace :scihist_digicoll do
  desc """Import all JSON import files present in /tmp/import.
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
    import_dir = Rails.root.join('tmp', 'import')
    # Import all the Assets, then all the Works,
    # and finally all the Collections.
    # The class_post_processing relies on this order
    # to function properly.

    #Total number of tasks: ingest each file
    # and then do post-processing for each of the 3 file types.

    total_tasks = Importers::FileSetImporter.file_paths.count
    # Generic works increment the progress bar twice.
    total_tasks += Importers::GenericWorkImporter.file_paths.count * 2
    total_tasks += Importers::CollectionImporter.file_paths.count

    if total_tasks == 0
      abort ("No files found to import in #{import_dir}")
    end
    progress_bar = ProgressBar.create(total: total_tasks, format: "%a %t: |%B| %R/s %c/%u %p%% %e")
    %w(FileSet GenericWork Collection).each do |s|
      importer_class = "Importers::#{s}Importer".constantize
      # For all the JSON files of a particular type,
      # instantiate an importer for that file and
      # perform the import.
      progress_bar.log("INFO: Importing #{s}s.")

      importer_class.file_paths.each do |path|
        # puts "Importing #{path}"
        importer = importer_class.new(path, progress_bar)
        # save_item() creates a new item, adds metadata to it,
        # and save it.
        # It does not take care of parent-child relationships.
        importer.save_item()
      end
      # Each importer class defines a post-processing function
      # that is run only after all items in its class have
      # already been ingested. For instance, generic_work_importer
      # subclasses class_post_processing with functionality that
      # links each Work with its child Works and Assets.
      importer_class.class_post_processing()
    end # exporters.each
  end # task

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

    total_tasks = Importers::FileSetImporter.file_paths.count
    total_tasks += Importers::GenericWorkImporter.file_paths.count
    total_tasks += Importers::CollectionImporter.file_paths.count
    progress_bar = ProgressBar.create(total: total_tasks, format: "%a %t: |%B| %R/s %c/%u %p%% %e")

    import_dir = Rails.root.join('tmp', 'import')
    report_file = File.new("report.txt", "w")
    %w(FileSet GenericWork Collection).each do |s|
      progress_bar.log("INFO: Auditing #{s}s")
      auditor_class = "Importers::#{s}Auditor".constantize
      auditor_class.file_paths.each do |path|
        auditor = auditor_class.new(path, report_file)
        auditor.check_item()
        progress_bar.increment
      end
    end # auditors.each
    report_file.close
  end # task



end # namespace
