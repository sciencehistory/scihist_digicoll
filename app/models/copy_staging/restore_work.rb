module CopyStaging
  # Loads a work into the app, from JSON serialized via corresponding SerializeWork class.
  #
  # These are normally called by scihist:copy_staging_work rake tasks, which
  # are called by `copy_data` capistrano task -- for copying a work from
  # staging to local dev instance.
  #
  # This normally restores while preserving PK and friendlier_id ids; if there are
  # same IDs in app already, there will be a db constraint violation and it will fail.
  #
  #     CopyStaging::RestoreWork.new(json_file: File.open("path/to/json.json")).restore
  #
  # WARNING: May not be safe for calling except in rake task, it changes attributes of the db
  # connection, should not be used when it might be sharing db connection. Registers shrine
  # storages not expected to persist past rake task. etc.
  class RestoreWork
    REMOTE_STORE_STORAGE_KEY = :remote_store_storage
    REMOTE_DERIVATIVES_STORAGE_KEY = :remote_derivatives_storage

    attr_accessor :json_file

    def initialize(json_file:)
      @json_file = json_file

      # make sure they get registered
      remote_store_storage
      remote_derivatives_storage
    end

    def restore
      Kithe::Model.transaction do
        begin
          # This magically gets postgres to not enforce integrity constraints.
          # This does mean we ARE able to insert data that violates integrity constraints,
          # they won't be enforced on transaction end either!
          # https://www.endpoint.com/blog/2015/01/28/postgres-sessionreplication-role
          Kithe::Model.connection.execute("SET session_replication_role TO 'replica'")

          input_hash["models"].each do |json_hash|
            model_class = json_hash.keys.first.classify.constantize
            attributes  = json_hash.values.first

            puts "Saving #{model_id_string(model_class, attributes)}/\n\n"

            model = model_class.new(attributes)
            model.save!

            if model_class <= Kithe::Asset
              restore_asset_file(model)
            elsif model_class <= Kithe::Derivative
              restore_derivative_file(model)
            end
          end
        ensure
          Kithe::Model.connection.execute("SET session_replication_role TO 'origin'")
        end
      end
    end

    private

    # just a nice human-readable identification of the model being restored,
    # attributes vary depending on type.
    def model_id_string(model_class, attributes)
      components = []

      components << model_class.name

      if model_class <= Kithe::Derivative
        components << attributes["asset_id"]
        components << attributes["key"]
      elsif model_class <= Kithe::Model
        components << attributes["id"]
        components << attributes["friendlier_id"]
        components << attributes["title"].slice(0, 30)
      end

      components.join("/")
    end

    def restore_asset_file(asset_model)
      puts "  -> Copying original file for #{asset_model.class.name}/#{asset_model.friendlier_id}\n\n"

      remote_file = Shrine::UploadedFile.new(asset_model.file.data.merge("storage" => REMOTE_STORE_STORAGE_KEY))
      Shrine.storages[:store].upload(remote_file, asset_model.file.id)
    end

    def restore_derivative_file(derivative_model)
      puts "  -> Copying derivative file for #{derivative_model.class.name}/#{derivative_model.id}/#{derivative_model.key}\n\n"

      remote_file = Shrine::UploadedFile.new(derivative_model.file.data.merge("storage" => REMOTE_DERIVATIVES_STORAGE_KEY))
      Shrine.storages[:kithe_derivatives].upload(remote_file, derivative_model.file.id)
    end

    def input_hash
      @input_hash ||= ActiveSupport::JSON.decode(json_file.read)
    end

    def remote_store_storage
      Shrine.storages[REMOTE_STORE_STORAGE_KEY] ||= Shrine::Storage::S3.new({
        bucket:            input_hash["shrine_s3_storage_staging"]["store"]["bucket_name"],
        prefix:            input_hash["shrine_s3_storage_staging"]["store"]["prefix"],
        access_key_id:     ScihistDigicoll::Env.lookup!(:aws_access_key_id),
        secret_access_key: ScihistDigicoll::Env.lookup!(:aws_secret_access_key),
        region:            ScihistDigicoll::Env.lookup!(:aws_region)
      })
    end

    def remote_derivatives_storage
      Shrine.storages[REMOTE_DERIVATIVES_STORAGE_KEY] ||= Shrine::Storage::S3.new({
        bucket:            input_hash["shrine_s3_storage_staging"]["kithe_derivatives"]["bucket_name"],
        prefix:            input_hash["shrine_s3_storage_staging"]["kithe_derivatives"]["prefix"],
        access_key_id:     ScihistDigicoll::Env.lookup!(:aws_access_key_id),
        secret_access_key: ScihistDigicoll::Env.lookup!(:aws_secret_access_key),
        region:            ScihistDigicoll::Env.lookup!(:aws_region)
      })
    end

  end
end
