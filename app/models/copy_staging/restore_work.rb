module CopyStaging
  # Loads a work into the app, from JSON serialized via corresponding SerializeWork class.
  #
  # These are normally called by scihist:copy_staging_work rake tasks, which
  # are called by the `heroku:copy_data` task -- for copying a work from
  # staging to local dev instance.
  #
  # This normally restores while preserving PK and friendlier_id ids; if there are
  # same IDs in app already, there will be a db constraint violation and it will fail.
  #
  #     CopyStaging::RestoreWork.new(json_file: File.open("path/to/json.json")).restore
  #
  # CONTEXT WARNING: Meant for use by rake task!
  #
  # This was written for use by the rake task, just extracting out the code for better
  # organization. Some choices were made that might cause problems if it were NOT run in a rake
  # task. Like use of threads, changing postgres session attributes, registering shrine storages.
  # All are fine in a short-lived single-purpose process, but might cause problems in
  # a multi-purpose long-running web app process.
  #
  # ## CONCURRENCY WARNING
  #
  # We use some multi-threaded concurrency for the operations to copy files/bytestreams
  # from staging to local dev.
  #
  # This works out well because when we are copying from S3 to S3, shrine optimizes to
  # an S3 API "COPY" operation -- we aren't doing any work or IO locally, but do have to wait
  # for confirmation from S3 that the copy succeeded. And it makes sense to do these waits in
  # parallel, even massively parallel.
  #
  # But if the local storage is local file system or something other than S3, this
  # could be disastrous. This object can take thread_pool_size as an init
  # argument, but the wrapping rake task isn't currently written to exersize that.
  class RestoreWork

    # Associate dev with staging shrine storage keys:
    ORIGINALS_STORAGE = {
      store:                         :remote_store_storage,      #non-video
      video_store:                   :remote_video_store_storage # video
    }
    DERIVATIVES_STORAGE = {
      kithe_derivatives:             :remote_derivatives_storage,
      restricted_kithe_derivatives:  :remote_restricted_derivatives_storage
    }

    attr_accessor :json_file, :thread_pool, :tracked_futures, :thread_pool_size

    # @param json_file path to file of json of the format we expect, normally
    #   exported from correspoinding SerializeWork file.
    #
    # @param thread_pool_size how big a thread pool to use for our parallel
    #   bytestream copy operations. See docs at top of class. Defaults to 50,
    #   could be faster if we made it unlimited, but could also be more disastrous.
    def initialize(json_file:, thread_pool_size: 50)
      @json_file = json_file
      @thread_pool_size = thread_pool_size
      @thread_pool = Concurrent::FixedThreadPool.new(thread_pool_size)
      @tracked_futures = Concurrent::Array.new
      @storage_map = ORIGINALS_STORAGE.merge(DERIVATIVES_STORAGE)
      register_remote_storages
    end

    def restore
      model_count = input_hash["models"].count

      Kithe::Model.transaction do
        begin
          # This magically gets postgres to not enforce integrity constraints.
          # This does mean we ARE able to insert data that violates integrity constraints,
          # they won't be enforced on transaction end either!
          # https://www.endpoint.com/blog/2015/01/28/postgres-sessionreplication-role
          Kithe::Model.connection.execute("SET session_replication_role TO 'replica'")

          input_hash["models"].each_with_index do |json_hash, i|
            model_class = json_hash.keys.first.classify.constantize
            attributes  = json_hash.values.first

            progress = "#{((i+1).to_f / model_count * 100).round(2)}%"
            puts "Saving #{model_id_string(model_class, attributes)} (#{progress})\n\n"

            model = model_class.new(attributes)
            model.save!

            if model_class <= Kithe::Asset
              restore_asset_file(model)

              model.file_derivatives.each do |key, derivative_uploaded_file|
                restore_derivative_file(derivative_uploaded_file, derivative_key: key, asset_id: model.friendlier_id)
              end
            end

            # let's keep from getting too far in front of the thread pool --
            # not totally sure this matters, and it does slowdown total throughput
            # some, but keeps our progress % count more accurate the way we are
            # currently doing it, and seems safer. The less often we block waiting,
            # the more throughput we get, so we do a generous *8.
            if tracked_futures.size > thread_pool_size * 8
              puts "...Waiting for file copies to catch up...\n\n"
              tracked_futures.each(&:value!)
              tracked_futures.clear
            end
          end
          puts "...Waiting for file copies to catch up...\n\n"
          tracked_futures.each(&:value!)
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

      if model_class <= Kithe::Model
        components << attributes["id"]
        components << attributes["friendlier_id"]
        components << attributes["title"].slice(0, 30)
      end

      components.join("/")
    end

    def restore_asset_file(asset_model)
      local_storage_key = asset_model.file.data['storage'].to_sym
      unless @storage_map.has_key? local_storage_key
         raise RuntimeError, "Unrecognized remote storage for asset #{asset_model.friendlier_id}: #{local_storage_key}"
      end
      tracked_futures << Concurrent::Promises.future_on(thread_pool) do
        puts "  -> Copying original file for #{asset_model.class.name}/#{asset_model.friendlier_id}\n\n"        
        copy_file( key: local_storage_key, file: asset_model.file)
      end
    end

    def restore_derivative_file(derivative_uploaded_file, asset_id:, derivative_key:)
      tracked_futures << Concurrent::Promises.future_on(thread_pool) do
        puts "  -> Copying derivative file for #{asset_id}/#{derivative_key}\n\n"
        copy_file(key: derivative_uploaded_file.storage_key, file: derivative_uploaded_file)
      rescue Aws::S3::Errors::NoSuchKey => e
        path = Shrine.storages[remote_storage_key].then {|s| [s.bucket&.name, s.prefix].compact.join('/')}
        puts "   ERROR: Could not find file to copy `#{remote_file.id}` on #{path}"
      end
    end

    # "Upload" a remote file to a local Shrine storage, effectively copying it.
    def copy_file(key:, file:)
      remote_metadata = file.data.merge("storage" => @storage_map[key])
      remote_file = Shrine::UploadedFile.new(remote_metadata)
      Shrine.storages[key].upload(remote_file,file.id)
    end

    def input_hash
      @input_hash ||= ActiveSupport::JSON.decode(json_file.read)
    end

    def register_remote_storages
      @storage_map.each_pair do |local_key, remote_key|
        Shrine.storages[remote_key] ||= Shrine::Storage::S3.new(
          bucket:            input_hash["shrine_s3_storage_staging"][local_key.to_s]["bucket_name"],
          prefix:            input_hash["shrine_s3_storage_staging"][local_key.to_s]["prefix"],
          access_key_id:     ScihistDigicoll::Env.lookup!(:aws_access_key_id),
          secret_access_key: ScihistDigicoll::Env.lookup!(:aws_secret_access_key),
          region:            ScihistDigicoll::Env.lookup!(:aws_region)
        )
      end
    end
  end
end