class OrphanS3Base
  attr_reader :show_progress_bar
  def initialize(show_progress_bar: false)
    @show_progress_bar = !!show_progress_bar
  end

  # Return a Shrine::Storage, for instance perhaps from `ScihistDigicoll::Env.shrine_store_storage`
  def shrine_storage
    raise TypeError.new("sub-class should implement")
  end

  # An intermediate prefix after the bucket prefix, if the directories named after pk UUI
  # are inside some other prefix we have to 'skip'.
  # Subclass can override to be non-nil if needed, for instance, might be "asset"
  def extra_prefix
    nil
  end

  # Sub-class can override to true, means we'll only check the path ending at pk UUID component, not
  # sub-parts.
  def check_base_paths_only?
    false
  end

  # base prefix from the shrine storage, combined with any specified prefix to search within
  # the storage, normalized to always end in '/'
  def search_prefix
    @search_prefix ||= [shrine_storage.prefix, extra_prefix, ""].compact.collect {|h| h.sub(/\/\Z/, '') }.join("/")
  end

  def s3_bucket_name
    @s3_bucket_name ||= shrine_storage.bucket.name
  end

  def s3_client
    @s3_client ||= shrine_storage.client
  end

  def report_orphans
    max_reports = 20
    orphans_found = 0

    report = find_orphans do |path, asset_id:, shrine_id_value:|
      orphans_found +=1

      if orphans_found == max_reports
        puts "Reported max #{max_reports} orphans, not listing subsquent...\n"
      elsif orphans_found < max_reports
        asset = Asset.where(id: asset_id).first

        puts "orphaned file!"
        puts "  bucket: #{s3_bucket_name}"
        puts "  s3 path: #{path}"
        puts "  asset_id: #{asset_id}"
        if asset.nil?
          puts "  asset missing"
        else
          puts "  asset friendlier_id: #{asset.friendlier_id}"
          puts "  asset file_data ->> id: #{asset.file_data["id"]}"
        end
        puts
      end
    end

    puts "\n\nTotal Asset count: #{report.asset_count}"
    puts "Checked #{report.files_checked} files on S3"
    puts "Found #{orphans_found} orphan files\n"
  end

  def delete_orphans
    delete_count = 0
    find_orphans do |path, asset_id:, shrine_id_value:|
      shrine_storage.bucket.object(path).delete
      puts "deleted: #{path}"
      delete_count += 1
    end
    puts "Deleted #{delete_count} orphaned objects"
  end

  private

  # iterate through all the keypaths in S#, based on our bucket and extra_prefix, yielding each one to block passed
  # by caller.
  #
  # If check_base_paths_only?, then instead of yielding each path, we only yield the top-level component of the path
  # after the bucket prefix and extra_prefix -- the component that should be the pk UUID.
  def each_s3_path
    delimiter = check_base_paths_only? ? "/" : nil

    s3_client.list_objects_v2(bucket: s3_bucket_name, prefix: search_prefix, delimiter: delimiter, max_keys: 1000).each do |s3_response|
      if delimiter
        s3_response.common_prefixes.each do |s3_obj|
          yield s3_obj.prefix
        end
      else
        s3_response.contents.each do |s3_obj|
          yield s3_obj.key
        end
      end
    end
  end

  # Yields to block for every orphan.
  # Returns an OpenStruct with total number of S3 files checked, total number of assets, etc.
  def find_orphans
    asset_count = Asset.count

    if show_progress_bar
      # Asset.count is just an estimate
      progress_bar = ProgressBar.create(total: asset_count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)
    end

    files_checked = 0

    each_s3_path do |s3_key|
      asset_id, shrine_path = parse_s3_path(s3_key)
      unless asset_with_path_exists?(asset_id, shrine_path)
        yield(s3_key, asset_id: asset_id, shrine_id_value: shrine_path)
      end

      files_checked += 1
      if progress_bar
        if progress_bar.total && progress_bar.progress + 1 >= progress_bar.total
          # more files than we expected, which makes sense if they were orphans...
          progress_bar.total = nil
        end
        progress_bar.increment
      end
    end

    return OpenStruct.new(
      files_checked: files_checked,
      asset_count: asset_count
    )
  end

  # We have an actual S3 path. We want to ignore the storage_prefix. What's remaining is
  # what we expect to be in a shrine `id` field for what shrine thinks of as the path on S3.
  # Also in our path is encoded the Asset UUID pk we expect to have that shrine id (if it's not orphaned).
  #
  # We return [asset_id, shrine_id_value]
  def parse_s3_path(s3_path)
    bucket_prefix = if shrine_storage.prefix
      Regexp.escape(shrine_storage.prefix.chomp('/') + '/')
    end

    intermediate_prefix = if extra_prefix
      Regexp.escape(extra_prefix.chomp('/') + '/')
    end

    s3_path =~ %r{\A#{bucket_prefix}(#{intermediate_prefix}([^/]+/).*)\Z}

    shrine_id_value = $1
    asset_id = $2 && $2.chomp("/")

    return [asset_id, shrine_id_value]
  end

  def asset_with_path_exists?(asset_id, shrine_path)
    unless asset_id && shrine_path
      return false
    end

    Asset.
      where(id: asset_id).
      where("file_data ->> 'id' = ?", shrine_path).
      exists?
  end
end
