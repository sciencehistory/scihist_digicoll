class OrphanS3VideoDerivatives

  attr_reader :s3_iterator, :shrine_storage, :show_progress_bar, :sample, :orphans_found
  def initialize(show_progress_bar: true)

    @sample = []
    @shrine_storage = ScihistDigicoll::Env.shrine_video_derivatives_storage
    @show_progress_bar = show_progress_bar

    @s3_iterator = S3PathIterator.new(
      shrine_storage: shrine_storage,
      show_progress_bar: show_progress_bar,
      progress_bar_total: video_asset_count,
    )
  end

  def video_asset_count
    @video_asset_count ||= Kithe::Asset.connection.select_one("select count(*) from kithe_models where kithe_model_type = 2 and file_data ->> 'storage' = 'video_store'")['count']
  end

  def delete_orphans
    delete_count = 0
    find_orphan_video_derivatives do |asset_id:, md5:, shrine_id:, s3_path:|
       shrine_storage.delete(shrine_id)
       s3_iterator.log "deleted: #{shrine_storage.bucket.name}: #{s3_path}"
       delete_count += 1
    end
    $stderr.puts "\nDeleted #{delete_count} sets of orphaned derivatives"
  end

  def report_orphans
    max_reports = 20
    @orphans_found = 0

    files_checked = find_orphan_video_derivatives do |asset_id:, md5:, shrine_id:, s3_path:|
      @orphans_found +=1

      if @orphans_found == max_reports
        s3_iterator.log "Reported max #{max_reports} orphans, not listing subsquent...\n"
      elsif @orphans_found < max_reports

        @sample << s3_url_for_path(s3_path)
        asset = Asset.where(id: asset_id).first

        s3_iterator.log "orphaned video derivative"
        s3_iterator.log "  bucket: #{shrine_storage.bucket.name}"
        s3_iterator.log "  s3 path: #{s3_path}"
        s3_iterator.log "  asset_id: #{asset_id}"
        s3_iterator.log "  expected md5: #{md5}"

        if asset.nil?
          s3_iterator.log "  asset missing"
        else
          s3_iterator.log "  actual md5:   #{asset.md5}"
        end
        s3_iterator.log ""
      end
    end

    $stderr.puts "\n\nTotal video asset count: #{video_asset_count}"
    $stderr.puts "Iterated through #{files_checked} tile files on S3"
    $stderr.puts "Found #{orphans_found} orphan files\n"
  end

  private




  # Will yield to block (asset_id, md5, shrine_id, s3_path) for each derivative
  # determined to be an orphan. Will return number of files checked.
  #
  # @yield [asset_id:, md5:, shrine_id:, s3_path:]
  def find_orphan_video_derivatives
    s3_iterator.each_s3_path do |s3_path|
      asset_id, md5, shrine_id = parse_s3_path(s3_path)
      if orphaned?(asset_id, md5) || !legitimate_hls_derivative?(s3_path)
        yield asset_id: asset_id, md5: md5, shrine_id: shrine_id, s3_path: s3_path
      end
    end
  end

  def bucket_prefix
    @bucket_prefix ||= if shrine_storage.prefix
      Regexp.escape(shrine_storage.prefix.chomp('/') + '/')
    else
      ''
    end
  end

  # We start with an actual S3 path.
  # We want to ignore the storage_prefix. What remains is shrine_id_value, 
  # which is what shrine thinks of as the path on S3 - and our way of accessing and deleting the file
  # if we determine it to be orphaned.
  #
  # In other words, shrine_storage.object(shrine_id_value).exists? should always return true.
  #
  # The path also contains the UUID pk of the Asset whose file (if it's not orphaned)
  # we would expect to find at shrine_storage.object(shrine_id_value) .
  #
  # For example, given:
  # @s3_path = "laptop.local/derivatives_video/hls/0eadfd9b-c36b-4b02-a5e1-63a00a259410/2160f6d44ed781f81e7a4a66d5a0b117/hls_extra_low_00001.ts"
  # prefix   = "laptop.local/derivatives_video"
  #
  # we get:
  #    asset_id        = "0eadfd9b-c36b-4b02-a5e1-63a00a259410"
  #    md5             = "2160f6d44ed781f81e7a4a66d5a0b117"
  #    shrine_id = "hls/0eadfd9b-c36b-4b02-a5e1-63a00a259410/2160f6d44ed781f81e7a4a66d5a0b117/hls_extra_low_00001.ts"
  # Note that the md5 is NOT the hash of the asset, but can still be used to confirm the association
  # between the derivative and the asset.
  def parse_s3_path(s3_path)
    shrine_id =  s3_path.delete_prefix(shrine_storage.prefix + "/")
    # shrine_id is the path we would use to delete the file:
    # puts shrine_storage.object(shrine_id).exists? # always true
    path_array = shrine_id.split('/')
    dir_name, asset_id, md5, deriv_filename = path_array
    #puts "Asset ID is #{asset_id}; md5 is #{md5}; the derivative filename is #{deriv_filename}"
    return [asset_id, md5, shrine_id]
  end

  def orphaned?(asset_id, md5)
    unless asset_id && md5
       return true
    end
    ! Asset.where(id: asset_id).where("(json_attributes->'hls_playlist_file_data' #>> '{}')::jsonb->>'id' = ?", "hls/#{asset_id}/#{md5}/hls.m3u8" ).exists?
  end

  def legitimate_hls_derivative?(s3_path)
    /hls\/[^\/]*\/[^\/]*\/hls[^\/]*\.(ts|m3u8)$/.match(s3_path)
  end

  # note that the s3_path is complete path on bucket, it might include a prefix
  # from the shrine storage already. We just want a complete good direct to S3 URL
  # as an identifier, it may not be accessible, it wont' use a CDN, etc.
  def s3_url_for_path(s3_path)
    if shrine_storage.respond_to?(:bucket)
      shrine_storage.bucket.object(s3_path).public_url
    else
      # we aren't S3 at all, not sure what we'll get...
      shrine_storage.url(s3_path)
    end
  end
end