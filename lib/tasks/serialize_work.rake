namespace :scihist do

  # Rake tasks meant to be called by the capistrano :copy_data task, which
  # ssh's to staging server and runs :serialize_work, saves the JSON output of such
  # to a file locally, and calls :restore_work with JSON file locally.
  #
  # You can also run the tasks manually, especially useful for debugging/development.
  namespace :copy_staging_work do

    # Intended to be called on staging server, usually by a capistrano :copy_data task.
    # Writes out json to STDOUT, which including model and shrine strorage
    # data, which will turn into input for :restore_work
    desc "write out serialized JSON for work and all it's children. Used by cap copy_data"
    task :serialize_work, [:work_friendlier_id] => :environment do |t, args|
      # Storage where original files live
      storage = Shrine.storages[:store]
      unless storage.kind_of?(Shrine::Storage::S3)
        raise ArgumentError, "We only know how to work with S3 storage for Shrine.storages[:store], not #{storage.class.name}"
      end

      parent = Work.find_by_friendlier_id!(args[:work_friendlier_id])


      # Recursive inline proc to take parent and all children and serialize
      # them to json.
      #
      # Uses model#attributes for data to serialize, this is potentially  less data than #to_json,
      #  #attributes seems to be what we really want without other stuff getting in the way.
      #
      # For each model, we serialize a one-element hash, where key is the class name,
      # value is the attributes.  Models could be works or assets, and specific sub-classes
      # of each.
      #
      serialize_proc = lambda do |model|
        model_attributes = model.attributes

        # hacky workaround
        # https://github.com/sciencehistory/kithe/pull/75
        if model.kind_of?(Kithe::Asset)
          model_attributes.delete("representative_id")
          model_attributes.delete("leaf_representative_id")
        end

        [{ model.class.name => model_attributes }] +
          model.members.flat_map do |member|
            serialize_proc.call(member)
          end
      end

      json_hashes = serialize_proc.call(parent)

      transfer_hash = {
        "models" => json_hashes,
        "shrine_s3_storage_staging" => {
          "bucket_name" => storage.bucket.name,
          "prefix" => storage.prefix
        }
      }

      puts(transfer_hash.to_json)
    end

    # Intended to be called on local dev server, usually by capistrano :copy_data task.
    # Argument is local file path to a JSON file output by :serialize_work task above,
    # on staging server.
    task :restore_work, [:json_file_path] => :environment do |t, args|
      json_input = ActiveSupport::JSON.decode(File.open(args[:json_file_path]).read)
      model_json = json_input["models"]

      # Create a shrine storage configured to point at staging, so we can instantiate
      # a shrine UploadedObject for it, to copy it locally. (Shrine S3 is actually smart
      # enough to issue an S3 "copy" command instead of actually shipping bytes around)
      #
      # This does require us to have AWS access keys configured locally with
      # read access to staging "store" originals bucket.
      Shrine.storages[:import_staging_store] = Shrine::Storage::S3.new({
        bucket:            json_input["shrine_s3_storage_staging"]["bucket_name"],
        prefix:            json_input["shrine_s3_storage_staging"]["prefix"],
        access_key_id:     ScihistDigicoll::Env.lookup(:aws_access_key_id),
        secret_access_key: ScihistDigicoll::Env.lookup(:aws_secret_access_key),
        region:            ScihistDigicoll::Env.lookup(:aws_region)
      })

      Kithe::Model.transaction do
        # This magically gets postgres to not enforce integrity constraints.
        # This does mean we ARE able to insert data that violates integrity constraints,
        # they won't be enforced on transaction end either!
        # https://www.endpoint.com/blog/2015/01/28/postgres-sessionreplication-role
        Kithe::Model.connection.execute("SET session_replication_role TO 'replica'")

        model_json.each do |json_hash|
          model_class = json_hash.keys.first.classify.constantize
          attributes = json_hash.values.first

          puts "Saving #{model_class}/#{attributes["id"]}/#{attributes["friendlier_id"]}/#{attributes["title"].slice(0, 30)}\n\n"

          model = model_class.new(attributes)
          model.save!

          if model_class < Kithe::Asset
            puts "  -> Copying original and creating local derivatives for Asset/#{model.friendlier_id}\n\n"

            # Copy file from staging; requires our local AWS key to have read access to remote S3
            remote_file = Shrine::UploadedFile.new(model.file.data.merge("storage" => "import_staging_store"))
            Shrine.storages[:store].upload(remote_file, model.file.id)

            # Make derivatives please. We could try COPYING the derivatives (like we are copying
            # the original), instead of of re-making them, but for now this is simpler (if slower).
            model.create_derivatives(lazy: true)
          end
        end

        Kithe::Model.connection.execute("SET session_replication_role TO 'origin'")
      end
    end
  end
end
