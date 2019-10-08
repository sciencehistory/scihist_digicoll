class OrphanS3Derivatives

  attr_reader :s3_iterator, :shrine_storage
  def initialize(show_progress_bar: true)
    @shrine_storage = ScihistDigicoll::Env.shrine_derivatives_storage

    @s3_iterator = S3PathIterator.new(
      shrine_storage: shrine_storage,
      show_progress_bar: show_progress_bar,
      check_base_paths_only: true
    )
  end

  def delete_orphans
    delete_count = 0
    s3_iterator.each_s3_path do |s3_path|
      asset_id = asset_id(s3_path)

      if orphaned?(asset_id)
        shrine_storage.delete_prefixed(asset_id)
        s3_iterator.log "deleted derivatives at: #{shrine_storage.bucket.name}: #{s3_path}"
        delete_count += 1
      end
    end
    $stderr.puts "\nDeleted #{delete_count} sets of orphaned derivatives"
  end

  def report_orphans
    max_reports = 20
    orphans_found = 0

    report = s3_iterator.each_s3_path do |s3_path|
      asset_id = asset_id(s3_path)

      if orphaned?(asset_id)
        orphans_found +=1

        if orphans_found == max_reports
          s3_iterator.log "Reported max #{max_reports} orphans, not listing subsquent...\n"
        elsif orphans_found < max_reports
          asset = Asset.where(id: asset_id).first

          s3_iterator.log "orphaned derivatives"
          s3_iterator.log "  bucket: #{shrine_storage.bucket.name}"
          s3_iterator.log "  s3 path: #{s3_path}"
          s3_iterator.log "  asset_id: #{asset_id}"
          if asset.nil?
            s3_iterator.log "  asset missing"
          end
          s3_iterator.log ""
        end
      end
    end

    $stderr.puts "\n\nTotal Asset count: #{report.asset_count}"
    $stderr.puts "Checked #{report.files_checked} files on S3"
    $stderr.puts "Found #{orphans_found} orphan files\n"
  end

  private

  def asset_id(s3_path)
    s3_path.split("/").last
  end


  def orphaned?(asset_id)
    return true unless asset_id

    ! Asset.where(id: asset_id).exists?
  end
end
