# TODO. Check all files not just the base prefix. To see if it is actually referenced by a Derivative model.

class OrphanS3Derivatives
  # We put some other things on the 'derivatives' s3, that we want to ignore and not consider orphaned
  IGNORE_PATH_PREFIXES = ["__sitemaps/"]

  attr_reader :s3_iterator, :shrine_storage

  def initialize(show_progress_bar: true)
    @shrine_storage = ScihistDigicoll::Env.shrine_derivatives_storage

    @s3_iterator = S3PathIterator.new(
      shrine_storage: shrine_storage,
      show_progress_bar: show_progress_bar,
      progress_bar_total: derivative_count
    )
  end

  def derivative_count
    @derivatives_count ||= Kithe::Derivative.count
  end

  def delete_orphans
    delete_count = 0
    s3_iterator.each_s3_path do |s3_path|
      next if IGNORE_PATH_PREFIXES.any? {|p| s3_path.start_with?(p) }

      asset_id, derivative_key, shrine_path = parse_s3_path(s3_path)

      if orphaned?(asset_id, derivative_key, shrine_path)
        shrine_storage.delete(shrine_path)
        s3_iterator.log "deleted derivative file at: #{shrine_storage.bucket.name}: #{s3_path}"
        delete_count += 1
      end
    end
    $stderr.puts "\nDeleted #{delete_count} orphaned derivatives"
  end

  def report_orphans
    max_reports = 40
    orphans_found = 0

    report = s3_iterator.each_s3_path do |s3_path|
      next if IGNORE_PATH_PREFIXES.any? {|p| p.start_with?(s3_path) }


      asset_id, derivative_key, shrine_path = parse_s3_path(s3_path)

      if orphaned?(asset_id, derivative_key, shrine_path)
        orphans_found +=1

        if orphans_found == max_reports
          s3_iterator.log "Reported max #{max_reports} orphans, not listing subsquent...\n"
        elsif orphans_found < max_reports
          asset = Asset.where(id: asset_id).first

          s3_iterator.log "orphaned derivative!"
          s3_iterator.log "  bucket: #{shrine_storage.bucket.name}"
          s3_iterator.log "  s3 path: #{s3_path}"
          s3_iterator.log "  asset_id: #{asset_id}"
          s3_iterator.log "  derivative_key: #{derivative_key}"
          if asset.nil?
            s3_iterator.log "  asset missing"
          else
            s3_iterator.log ""
            deriv = Kithe::Derivative.where(asset_id: asset_id, key: derivative_key).first
            s3_iterator.log "  derivative_pk: #{deriv&.id || 'missing'}"
            s3_iterator.log "  derivative file path: #{deriv&.file&.id || 'missing'}"
          end
          s3_iterator.log ""
        end
      end
    end

    $stderr.puts "\n\nTotal Asset count: #{Asset.count}"
    $stderr.puts "Kithe::Derivative.count: #{derivative_count}"
    $stderr.puts "Checked #{report.files_checked} files on S3"
    $stderr.puts "Found #{orphans_found} orphan files\n"
  end

  private

  def parse_s3_path(s3_path)
    s3_path =~ %r{(([^/]+)/([^/]+)/[^/]+)\Z}

    shrine_path = $1
    asset_pk = $2
    derivative_key = $3

    return [asset_pk, derivative_key, shrine_path]
  end


  def orphaned?(asset_id, derivative_key, shrine_id)
    return true unless asset_id.present? && derivative_key.present?

    ! Kithe::Derivative.where(asset_id: asset_id, key: derivative_key).where("file_data ->> 'id' = ?", shrine_id).exists?
  end
end
