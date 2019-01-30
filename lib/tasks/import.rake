# bundle exec rake scihist_digicoll:import
namespace :scihist_digicoll do
  desc "Import the entire collection from JSON files"
  task :import => :environment do
    import_dir = Rails.root.join('tmp', 'import')
    %w(FileSet GenericWork Collection).each do |s|
      importer_class = "#{s}Importer".constantize
      importee_class = importer_class.importee
      importer_class.file_paths.each do |path|
        puts "Importing #{path}"
        importer = importer_class.new(path)
        importer.save_item()
        unless importer.errors.full_messages == []
          puts importer.errors.full_messages
          byebug
        end
        sleep 10
      end
      importer_class.class_post_processing()
    end # exporters.each
  end # task
end # namespace