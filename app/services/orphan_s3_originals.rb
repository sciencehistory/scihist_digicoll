class OrphanS3Originals
  attr_reader :s3_iterator, :extra_prefix, :shrine_storage
  def initialize(show_progress_bar: true)
    @extra_prefix = "asset"
    @shrine_storage = ScihistDigicoll::Env.shrine_store_storage

    @s3_iterator = S3PathIterator.new(
      shrine_storage: shrine_storage,
      extra_prefix: extra_prefix,
      show_progress_bar: show_progress_bar
    )
  end

  def report_orphans
    max_reports = 20
    orphans_found = 0

    report = s3_iterator.each_s3_path do |s3_key|
      asset_id, shrine_path = parse_s3_path(s3_key)

      if orphaned?(asset_id, shrine_path)
        orphans_found +=1

        if orphans_found == max_reports
          s3_iterator.log "Reported max #{max_reports} orphans, not listing subsquent...\n"
        elsif orphans_found < max_reports
          asset = Asset.where(id: asset_id).first

          s3_iterator.log "orphaned file!"
          s3_iterator.log "  bucket: #{s3_bucket_name}"
          s3_iterator.log "  s3 path: #{path}"
          s3_iterator.log "  asset_id: #{asset_id}"
          if asset.nil?
            s3_iterator.log "  asset missing"
          else
            s3_iterator.log "  asset friendlier_id: #{asset.friendlier_id}"
            s3_iterator.log "  asset file_data ->> id: #{asset.file_data["id"]}"
          end
          s3_iterator.log ""
        end
      end
    end

    $stderr.puts "\n\nTotal Asset count: #{report.asset_count}"
    $stderr.puts "Checked #{report.files_checked} files on S3"
    $stderr.puts "Found #{orphans_found} orphan files\n"
  end

  def delete_orphans
    delete_count = 0
    s3_iterator.each_s3_path do |s3_key|
      asset_id, shrine_path = parse_s3_path(s3_key)

      if orphaned?(asset_id, shrine_path)
        shrine_storage.bucket.object(path).delete
        s3_iterator.log "deleted: #{shrine_storage.bucket.name}: #{path}"
        delete_count += 1
      end
    end
    puts "Deleted #{delete_count} orphaned objects"
  end

  private


  def orphaned?(asset_id, shrine_path)
    unless asset_id && shrine_path
      return true
    end

    ! Asset.
        where(id: asset_id).
        where("file_data ->> 'id' = ?", shrine_path).
        exists?
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



end
