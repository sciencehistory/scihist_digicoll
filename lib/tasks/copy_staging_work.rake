namespace :scihist do

  # Rake tasks normally called by the heroku:copy_data task, which
  # connects to heroku staging server and runs :serialize_work, saves the JSON output of such
  # to a file locally, and calls :restore_work with JSON file locally.
  #
  # You can also run the tasks manually, especially useful for debugging/development.
  namespace :copy_staging_work do

    # Intended to be called on deployed staging server, usually by heroku:copy_data task.
    # Writes out json to STDOUT, which including model and shrine strorage
    # data, which will turn into input for :restore_work
    desc "write out serialized JSON for work and all it's children. Used by heroku:copy_data"
    task :serialize_work, [:work_friendlier_id] => :environment do |t, args|
      parent = Work.find_by_friendlier_id!(args[:work_friendlier_id])

      puts CopyStaging::SerializeWork.new(parent).to_json
    end

    # Intended to be called on local dev server, usually by heroku:copy_data task.
    # Argument is local file path to a JSON file output by :serialize_work task above,
    # on staging server.
    desc "restore Work from JSON serialized by :serialize_work"
    task :restore_work, [:json_file_path] => :environment do |t, args|
      Kithe::Indexable.index_with(batching: true) do
        CopyStaging::RestoreWork.new(json_file: File.open(args[:json_file_path])).restore
      end
    end
  end
end
