require 'tty-command'

# DZI (Deep Zoom Image) is a format for tiled images for deep-zoom and pan, that we use with OpenSeadragon
# JS viewer. It consists of a *.dzi "manifest" file, and a bunch of tiles in subdirs of a `*_files` dir named
# after the *.dzi manifest, and next to it in the file system/URL structure. https://en.wikipedia.org/wiki/Deep_Zoom
#
# We do not use Shrine attachment to keep track of our DZI files, or otherwise register whether they have been
# created or at what address in our database. Rather, we just use a predictable URL for the DZI for a given
# Asset. The URL is based on both Asset ID and current MD5 hash, so it can be cached forever (will change
# if file changes).
#
# We currently store all DZI files with public ACLs on S3, like other derivatives. We don't currently implement
# access control for DZIs. (Would have to figure out how to deal with that plus, ideally, HTTP cacheability)
#
# This model class has logic for creating and deleting DZI on an S3 bucket (or other shrine storage, hypothetically).
# It also includes methods for seeing if a DZI currently exists (will make a request to S3), and getting a URL
# to the manifest file. (#url delegates to the Shrine method, so all shrine #url arguments are possible,
# including S3 specific ones, such as public: true/false.)
#
# We use ActiveRecord callbacks to hook into AR model lifecycle to create and delete the DZI files appropriately.
# We actually hook into the shrine/kithe after_promotion hook to create DZI after the asset is fully promoted,
# but ordinary AR callbacks to delete a stale DZI if an Asset is deleted or has it's file changed. Callbacks
# are registered in Asset, to class methods here. Creation and deletion when triggered by lifecycle hooks
# is done in background ActiveJobs.
class DziFiles
  class_attribute :vips_command, default: "vips"
  class_attribute :jpeg_quality, default: "85"
  class_attribute :shrine_storage_key, default: :dzi_storage

  delegate :exists?, :url, to: :dzi_uploaded_file

  attr_reader :asset, :md5

  def initialize(asset, md5:asset.md5)
    @asset = asset
    @md5 = md5 || asset.md5
    raise ArgumentError.new("need an md5") if md5.blank?
    raise ArgumentError.new*("need an asset") if asset.nil?
  end

  # The main .dzi file as a Shrine::UploadedFile.
  # It may or may not actually exist, depending on if it's been created.
  #
  # You can do things like call #exists? or #url on it, per Shrine::UploadedFile API.
  #
  # @return [Shrine::UploadedFile]
  def dzi_uploaded_file
    @dzi_uploaded_file ||= Shrine::UploadedFile.new(
      "id" => "#{base_file_path}.dzi",
      "storage" => shrine_storage_key
    )
  end



  # Creates the DZI and uploads to remote storage. This method works inline,
  # it does not call a bg job or work async. It will normally be called
  # in a bg job.
  def create
    create_and_yield do |tmp_output_dir|
      upload(tmp_output_dir)
    end
  end

  # Deletes ALL files associated with a dzi set, the main dzi and in _files subdir.
  # Will work inline.
  def delete
    self.class.delete(dzi_uploaded_file.id)
  end

  # class method to delete without a model, so we can easily delete DZI's after the
  # model/DB record is already deleted and we don't have it anymore, in a bg job.
  #
  # The arg is the shrine id (path) of the *.dzi file.
  def self.delete(dzi_file_id, storage_key: shrine_storage_key)
    storage = Shrine.storages[storage_key]

    # No list files or delete files at prefix built into shrine, so we gotta
    # do it ourselves for storage types we want to support.
    deleter = case storage
    when Shrine::Storage::S3
      S3PrefixDeleter
    when Shrine::Storage::FileSystem
      FileSystemPrefixDeleter
    else
      raise TypeError.new("Don't know how to delete for storage type #{destination_storage.class}")
    end

    Shrine::UploadedFile.new(
      "id" => dzi_file_id,
      "storage" => storage_key
    ).delete


    dir = dzi_file_id.sub(/\.dzi$/, "_files/")
    deleter.new(storage: storage, clear_prefix: dir).clear!
  end

  # @yield string path where the dzi files are. They will be cleaned up (deleted)
  #   after block yield is finished.
  def create_and_yield
    asset.file.download do |original_file|
      Dir.mktmpdir("dzi_#{asset.friendlier_id}_") do |tmp_output_dir|
        vips_output_pathname = Pathname.new(tmp_output_dir).join(base_file_path)
        FileUtils.mkdir_p(vips_output_pathname.dirname)

        TTY::Command.new(printer: :null).run(vips_command, "dzsave", original_file.path, vips_output_pathname.to_s, "--suffix", ".jpg[Q=#{jpeg_quality}]")

        yield tmp_output_dir
      end
    end
  end

  # Just takes all files in tmp_output_dir passed in, and uploads them at exactly the
  # path they have (with input arg as base) to the remote storage.
  def upload(tmp_output_dir)
    Dir.glob("#{tmp_output_dir}/**/*", base: "#{tmp_output_dir}/").each do |path|
      next if File.directory?(path)
      upload_path = path.delete_prefix("#{tmp_output_dir}/")

      File.open(path) do |file|
        destination_storage.upload(file, upload_path)
      end
    end
  end

  # includes asset ID (actual PK, it's long), and a digest checksum,
  # so it will be unique to actual file content, cacheable forever, and
  # automatically not used when file content changes.
  def base_file_path
    "#{asset.id}/md5_#{md5}"
  end


  # Just a container for some methods used as ActiveRecord callbacks for
  # DZI lifecycle management. Registered on Asset class in after_commit
  # and after_promotion registrations.
  module ActiveRecordCallbacks
    def self.after_promotion(asset)
      # we're gonna use the same kithe promotion_directives for derivatives to
      # control how we do dzi
      Kithe::TimingPromotionDirective.new(
          key: :create_derivatives,
          directives: asset.file_attacher.promotion_directives) do |directive|

        if directive.inline?
          DziFiles.new(asset).create
        elsif directive.background?
          CreateDziJob.perform_later(asset)
        end
      end
    end

    def self.after_commit(asset)
      if asset.destroyed?
        # we're gonna use the same kithe promotion_directives for :delete to
        # control how we do dzi deletion too.
        Kithe::TimingPromotionDirective.new(
            key: :delete,
            directives: asset.file_attacher.promotion_directives) do |directive|

          if directive.inline?
            asset.dzi_file.delete
          elsif directive.background?
            DeleteDziJob.perform_later(asset.dzi_file.dzi_uploaded_file.id)
          end
        end
      else
        # file changed, need to delete an old dzi?
        old_file_data, new_file_data = asset.file_data_previous_change
        if old_file_data.present?
          if old_file_data.kind_of?(String) # not sure why this happens, it should be JSON already
            old_file_data = JSON.parse(old_file_data)
          end
          if old_file_data["id"] != new_file_data["id"] &&
             old_md5 = old_file_data.dig("metadata", "md5")

             old_id = DziFiles.new(asset, md5: old_md5).dzi_uploaded_file.id
             DeleteDziJob.perform_later(old_id)
           end
        end
      end
    end
  end

  private

  def destination_storage
    Shrine.storages[shrine_storage_key]
  end

  # list/delete at prefix isn't (yet) included in shrine, so we annoyingly
  # gotta do it for the shrine storage types we might want ourselves.
  class S3PrefixDeleter
    attr_reader :prefix, :total_prefix, :storage

    def initialize(storage:, clear_prefix:)
      unless storage.kind_of?(Shrine::Storage::S3)
        raise ArgumentError("storage must be a Shrine::Storage::S3")
      end

      @storage = storage
      @prefix = prefix
      @total_prefix = File.join([storage.prefix, clear_prefix].compact).to_s
    end

    # copy/pasted/modifed from Shrine::Storage::S3#clear!, to let us
    # just clear a prefix, still using efficient calls.
    def clear!
      objects_to_delete = Enumerator.new do |yielder|
        storage.bucket.objects(prefix: total_prefix).each do |object|
          yielder << object
        end
      end

      # Batches the deletes...
      objects_to_delete.each_slice(1000) do |objects_batch|
        delete_params = { objects: objects_batch.map { |object| { key: object.key } } }
        storage.bucket.delete_objects(delete: delete_params)
      end
    end
  end

  class FileSystemPrefixDeleter
    attr_reader :prefix, :total_prefix, :storage

    def initialize(storage:, clear_prefix:)
      unless storage.kind_of?(Shrine::Storage::FileSystem)
        raise ArgumentError("storage must be a Shrine::Storage::FileSystem")
      end

      @storage = storage
      @prefix = prefix
      @total_prefix = File.join(storage.directory, clear_prefix).to_s
    end
    def clear!
      if Dir.exist?(total_prefix)
        FileUtils.remove_dir(total_prefix)
      end
    end
  end
end
