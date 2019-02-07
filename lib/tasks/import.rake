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
    import_dir = Rails.root.join('tmp', 'import')
    # Import all the Assets, then all the Works,
    # and finally all the Collections.
    # The class_post_processing relies on this order
    # to function properly.
    %w(FileSet GenericWork Collection).each do |s|
      importer_class = "#{s}Importer".constantize
      importee_class = importer_class.importee
      # For all the JSON files of a particular type,
      # instantiate an importer for that file and
      # perform the import.
      importer_class.file_paths.each do |path|
        puts "Importing #{path}"
        importer = importer_class.new(path)
        # save_item() creates a new item, and adds metadata to it,
        # and save it.
        # It does not take care of parent-child relationships.
        importer.save_item()
        unless importer.errors == []
          # For now, we're using nohup.out as the error report mechanism / log.
          puts importer.errors
        end
        # These sleep intervals are currently set to zero.
        sleep importer.how_long_to_sleep
      end
      # Each importer class defines a post-processing function
      # that is run only after all items in its class have
      # already been ingest. For instance, generic_work_importer
      # subclasses class_post_processing with functionality that
      # links each Work with its child Works and Assets.
      importer_class.class_post_processing()
    end # exporters.each
  end # task
end # namespace