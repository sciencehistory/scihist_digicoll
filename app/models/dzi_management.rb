require 'tty-command'

class DziManagement
  class_attribute :vips_command, default: "vips"
  class_attribute :jpeg_quality, default: "85"
  class_attribute :shrine_storage_key, default: :dzi_storage

  delegate :exists?, :url, to: :dzi_uploaded_file

  attr_reader :asset

  def initialize(asset)
    @asset = asset
  end

  # The main .dzi file as a Shrine::UploadedFile.
  # It may or may not actually exist, depending on if it's been created.
  #
  # You can do things like call #exists? or #url on it, per Shrine::UploadedFile API.
  #
  # @return [Shrine::UploadedFile]
  def dzi_uploaded_file
    @dzi_uploaded_file ||= Shrine::UploadedFile.new(
      "id" => "#{base_file_name}.dzi",
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

  # @yield string path where the dzi files are. They will be cleaned up (deleted)
  #   after block yield is finished.
  def create_and_yield
    asset.file.download do |original_file|
      Dir.mktmpdir("dzi_#{asset.friendlier_id}_") do |tmp_output_dir|
        vips_output_arg = Pathname.new(tmp_output_dir).join(base_file_name).to_s

        TTY::Command.new(printer: :null).run(vips_command, "dzsave", original_file.path, vips_output_arg, "--suffix", ".jpg[Q=#{jpeg_quality}]")

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
  def base_file_name
    "#{asset.id}_md5_#{asset.md5}"
  end


  private

  def destination_storage
    Shrine.storages[shrine_storage_key]
  end



end
