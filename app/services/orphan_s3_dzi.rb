class OrphanS3Dzi

  attr_reader :s3_iterator, :shrine_storage
  def initialize(show_progress_bar: true)
    @shrine_storage = ScihistDigicoll::Env.shrine_dzi_storage

    # In our actual corpus so far, we have around 480 tiles per asset.
    # Not all assets are images. But this is a rough count.
    estimated_tile_count = asset_count * 480

    @s3_iterator = S3PathIterator.new(
      shrine_storage: shrine_storage,
      show_progress_bar: show_progress_bar,
      progress_bar_total: estimated_tile_count
    )
  end

  def asset_count
    @asset_count ||= Asset.count
  end

  def delete_orphans
    delete_count = 0
    report = s3_iterator.each_s3_path do |s3_path|
      # We only care about .dzi manifests, we're not gonna check every tile
      next unless s3_path.end_with?(".dzi")

      asset_id, md5, shrine_id = parse_s3_path(s3_path)

      if orphaned?(asset_id, md5)
        # delete .dzi file
        shrine_storage.delete(shrine_id)
        # delete all tiles using shrine storage delete_prefixed
        shrine_storage.delete_prefixed(shrine_id.sub(".dzi", "_files/"))
        s3_iterator.log "deleted all DZI tiles for: #{shrine_storage.bucket.name}: #{s3_path}"
        delete_count += 1
      end
    end
    $stderr.puts "\nDeleted #{delete_count} sets of orphaned derivatives"
  end

  def report_orphans
    max_reports = 20
    orphans_found = 0

    report = s3_iterator.each_s3_path do |s3_path|
      # We only care about .dzi manifests, we're not gonna check every tile
      next unless s3_path.end_with?(".dzi")

      asset_id, md5 = parse_s3_path(s3_path)

      if orphaned?(asset_id, md5)
        orphans_found +=1

        if orphans_found == max_reports
          s3_iterator.log "Reported max #{max_reports} orphans, not listing subsquent...\n"
        elsif orphans_found < max_reports
          asset = Asset.where(id: asset_id).first

          s3_iterator.log "orphaned DZI"
          s3_iterator.log "  bucket: #{shrine_storage.bucket.name}"
          s3_iterator.log "  .dzi s3 path: #{s3_path}"
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
    end

    $stderr.puts "\n\nTotal Asset count: #{asset_count}"
    $stderr.puts "Iterated through #{report.files_checked} tile files on S3"
    $stderr.puts "Found #{orphans_found} orphan files\n"
  end

  private

  def parse_s3_path(s3_path)
    bucket_prefix = if shrine_storage.prefix
      Regexp.escape(shrine_storage.prefix.chomp('/') + '/')
    end

    s3_path =~ %r{\A#{bucket_prefix}(([^/]+/)md5_(.*).dzi)\Z}

    shrine_id = $1
    asset_id = $2.chomp('/')
    md5 = $3

    return [asset_id, md5, shrine_id]
  end

  def orphaned?(asset_id, md5)
    unless asset_id && md5
      return true
    end

    ! Asset.where(id: asset_id).where("file_data -> 'metadata' ->> 'md5' = ?", md5).exists?
  end
end
