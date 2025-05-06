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
  DEFAULT_SHRINE_STORAGE_KEY = :dzi_storage
  CACHE_VERSION = "1" # included in location, so we can bump to bust cache when derivation changes. Since we cache these forever in cloudfront.

  class_attribute :vips_command, default: "vips"
  class_attribute :jpeg_quality, default: "85"

  delegate :dzi_manifest_file, to: :asset
  delegate :exists?, :url, to: :dzi_manifest_file, allow_nil: true

  attr_reader :asset, :md5

  def initialize(asset, md5:asset.md5)
    @asset = asset
    @md5 = md5 || asset.md5
    raise ArgumentError.new("need an md5") if md5.blank?
    raise ArgumentError.new*("need an asset") if asset.nil?
  end


  # Creates the DZI and uploads to remote storage. This method works inline,
  # it does not call a bg job or work async. It will normally be called
  # in a bg job.
  def create(storage_key: DEFAULT_SHRINE_STORAGE_KEY)
    create_and_yield do |tmp_output_dir|
      upload(tmp_output_dir, storage_key: storage_key)
    end

    # assign file metadata pointing to an existing file
    asset.dzi_manifest_file_attacher.set(Shrine::UploadedFile.new(
      "id" => "#{base_file_path_to_use}.dzi",
      "storage" => storage_key.to_s,
      "metadata" => {
        "created_at" => Time.current.utc.iso8601.to_s,
        "vips_command" => vips_command_args("$ORIG_FILE", "$OUTPUT_BASE").join(" "),
        "vips_version" => @captured_vips_version
      }
    ))

    asset.save!
  end

  # Deletes ALL files associated with a dzi set, the main dzi and in _files subdir.
  # Will work inline.
  def delete
    return unless dzi_manifest_file.present?

    self.class.delete(dzi_manifest_file&.id, storage_key: dzi_manifest_file&.storage_key)
    unless asset.destroyed?
      asset.dzi_manifest_file_attacher.set(nil)
      asset.save!
    end
  end

  # class method to delete without a model, so we can easily delete DZI's after the
  # model/DB record is already deleted and we don't have it anymore, in a bg job.
  #
  # The arg is the shrine id (path) of the *.dzi file.
  def self.delete(dzi_file_id, storage_key: DEFAULT_SHRINE_STORAGE_KEY)
    unless dzi_file_id.present?
      raise ArgumentError.new("required dzi_file_id was nil")
    end

    storage = Shrine.storages[storage_key.to_sym]

    # Delete manifest .dzi file
    Shrine::UploadedFile.new(
      "id" => dzi_file_id,
      "storage" => storage_key.to_s
    ).delete

    # Delete tiles
    dir = dzi_file_id.sub(/\.dzi$/, "_files/")
    storage.delete_prefixed(dir)
  end

  # @yield string path where the dzi files are. They will be cleaned up (deleted)
  #   after block yield is finished.
  def create_and_yield
    raise ArgumentError.new("Can only create DZI from assets of type 'image/'") unless asset.content_type&.start_with?("image/")

    color_corrected_path = nil

    asset.file.download do |original_file|
      Dir.mktmpdir("dzi_#{asset.friendlier_id}_") do |tmp_output_dir|
        vips_output_pathname = Pathname.new(tmp_output_dir).join(base_file_path_to_use)
        FileUtils.mkdir_p(vips_output_pathname.dirname)

        out, err = TTY::Command.new(printer: :null).run(*vips_command_args(original_file.path, vips_output_pathname))
        out =~ /vips[ \-](\d+\.\d+\.\d+.*$)/

        if $1
          @captured_vips_version = $1
        end

        # Due to bug in some versions of vips, may leave an empty .dz file, remove it
        FileUtils.rm("#{vips_output_pathname}.dz", force: true)

        yield tmp_output_dir
      end
    end
  end

  def vips_command_args(original_file_path, vips_output_pathname)
    # `vips` dzsave will corrupt colors unless original TIFF is in srgb. Because it removes color
    # profile info, but does not do color transformation.
    #
    # So we use this more complex invocation that should properly convert to sRGB too.
    #
    # https://github.com/libvips/libvips/discussions/4470
    #

    [
      vips_command,
    "--version",
      "icc_transform",
      "--embedded",
      original_file_path,
      "#{vips_output_pathname}.dz[container=fs,suffix=.jpg[Q=#{jpeg_quality}]]",
      "srgb"
    ]
  end



  # Just takes all files in tmp_output_dir passed in, and uploads them at exactly the
  # path they have (with input arg as base) to the remote storage, properly next
  # to the current manifest file.
  #
  # Uses concurrent-ruby to do the uploads concurrently, which speeds things up
  # significantly, currently with a thread pool of 8 threads.
  # http://ruby-concurrency.github.io/concurrent-ruby/master/file.promises.out.html
  def upload(tmp_output_dir, storage_key: DEFAULT_SHRINE_STORAGE_KEY)
    thread_pool = Concurrent::FixedThreadPool.new(8, auto_terminate: false)
    futures = []

    destination_storage = Shrine.storages[storage_key.to_sym]

    Dir.glob("#{tmp_output_dir}/**/*", base: "#{tmp_output_dir}/").each_with_index do |path, i|
      next if File.directory?(path)

      futures << Concurrent::Promises.future_on(thread_pool) do
        upload_path = path.delete_prefix("#{tmp_output_dir}/")

        File.open(path) do |file|
          destination_storage.upload(file, upload_path)
        end
      end
    end

    # wait for all of them to complete. and raise if one of them raised
    Concurrent::Promises.zip(*futures).value!
  ensure
    thread_pool.kill if thread_pool
  end

  # includes asset ID (actual PK, it's long), and a digest checksum,
  # so it will be unique to actual file content, cacheable forever, and
  # automatically not used when file content changes.
  def base_file_path_to_use
    "#{asset.id}/md5_#{md5}_#{CACHE_VERSION}"
  end
end
