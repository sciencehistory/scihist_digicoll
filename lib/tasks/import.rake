# bundle exec rake scihist_digicoll:import
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

    require Rails.root.join('app', 'importers', 'importer.rb')
    require Rails.root.join('app', 'importers', 'file_set_importer.rb')
    require Rails.root.join('app', 'importers', 'generic_work_importer.rb')
    require Rails.root.join('app', 'importers', 'collection_importer.rb')

    import_dir = Rails.root.join('tmp', 'import')
    # Import all the Assets, then all the Works,
    # and finally all the Collections.
    # The class_post_processing relies on this order
    # to function properly.

    #Total number of tasks: ingest each file
    # and then do post-processing for each of the 3 file types.

    total_tasks = Import::FileSetImporter.file_paths.count
    # Generic works increment the progress bar twice.
    total_tasks += Import::GenericWorkImporter.file_paths.count * 2
    total_tasks += Import::CollectionImporter.file_paths.count


    progress_bar = ProgressBar.create(total: total_tasks, format: "%a %t: |%B| %R/s %c/%u %p%% %e")

    %w(FileSet GenericWork Collection).each do |s|
      importer_class = "Import::#{s}Importer".constantize
      importee_class = importer_class.importee
      # For all the JSON files of a particular type,
      # instantiate an importer for that file and
      # perform the import.
      progress_bar.log("INFO: Importing #{s}s.")

      importer_class.file_paths.each do |path|
        # puts "Importing #{path}"
        importer = importer_class.new(path, progress_bar)
        # save_item() creates a new item, and adds metadata to it,
        # and save it.
        # It does not take care of parent-child relationships.
        importer.save_item()
        # These sleep intervals are currently set to zero.
        sleep importer.how_long_to_sleep
      end
      # Each importer class defines a post-processing function
      # that is run only after all items in its class have
      # already been ingest. For instance, generic_work_importer
      # subclasses class_post_processing with functionality that
      # links each Work with its child Works and Assets.
      importer_class.class_post_processing()
      #progress_bar.increment
    end # exporters.each
  end # task

  task :audit_import => :environment do

    require Rails.root.join('app', 'importers', 'auditor.rb')
    require Rails.root.join('app', 'importers', 'file_set_auditor.rb')
    require Rails.root.join('app', 'importers', 'generic_work_auditor.rb')
    require Rails.root.join('app', 'importers', 'collection_auditor.rb')

    import_dir = Rails.root.join('tmp', 'import')
    report_file = File.new("report.txt", "w")
    %w(FileSet GenericWork Collection).each do |s|
      puts "Auditing #{s}s"
      auditor_class = "Import::#{s}Auditor".constantize
      importee_class = auditor_class.importee
      auditor_class.file_paths.each do |path|
        auditor = auditor_class.new(path, report_file)
        auditor.check_item()
      end
    end # auditors.each
    report_file.close
  end # task



end # namespace
