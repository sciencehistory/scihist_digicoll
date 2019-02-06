# bundle exec rake scihist_digicoll:import
namespace :scihist_digicoll do
  desc """Import all JSON files present in /tmp/import.
  To generate the JSON files, see instructions in lib/tasks/export.rake
  in project https://github.com/sciencehistory/chf-sufia/.
  The export files will be created within that project's tmp/export .
  Move them to a corresponding tmp/import file in this project,
  and finally, run `bundle exec rake scihist_digicoll:import`.

  Note: this import will DELETE AND OVERWRITE Works and Collections
  in scihist_digicoll that have the same friendlier_id.

  However, if an existing Asset a) has the same friendlier_id and b)
  contains an identical file (as determined by the sha1 hash), we
  consider it hasn't changed, and leave it be.
  """

  task :import => :environment do
    import_dir = Rails.root.join('tmp', 'import')
    %w(FileSet GenericWork Collection).each do |s|
      importer_class = "#{s}Importer".constantize
      importee_class = importer_class.importee
      importer_class.file_paths.each do |path|
        puts "Importing #{path}"
        importer = importer_class.new(path)
        importer.save_item()
        unless importer.errors == []
          puts importer.errors
          #TODO make a proper error report
          byebug
        end
        sleep importer.how_long_to_sleep
      end
      importer_class.class_post_processing()
    end # exporters.each
  end # task
end # namespace