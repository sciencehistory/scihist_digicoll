# Derivatives are stored  on S3 at:
#
#     ./{asset_uuid_pk}/{derivative_type_name}/{random_string_suffix}
#
# Eg:
#
#     /00968a6c-957a-46a9-817a-a7893aeafed0/download_large/80276f556523f9619f3a5e3a473f609c.jpg
#
# The `./` may be bucket root, or may be at a prefix inside a bucket, depending on
# how our `shrine-shrine_derivatives_storage` is configured.
#
# This class will use S3 API to iterate through ALL keys in configured shrine_store_storage,
# for each one try to parse out the UUID-pk and derivatie key from path. Then it will look
# in the postgres database to make sure a corresponding Derivative row exists, and points to the
# found object on S3.
#
# If all those things are not true, the S3 key is considered "orphaned". This class can be used to
# report on all discovered orphaned files, or to actually _delete_ orphaned files.  This class
# is normally called from a rake task.
#
# Certain things we store in the derivatives bucket but which are not derivatives, are intentionally
# ignored (eg in "__sitemaps/")
#
#
class OrphanS3Derivatives
  # We put some other things on the 'derivatives' s3, that we want to ignore and not consider orphaned
  IGNORE_PATH_PREFIXES = ["__sitemaps/", "google"]

  attr_reader :s3_iterator, :shrine_storage, :files_checked, :orphans_found, :delete_count, :sample

  # @param show_progress_bar [Boolean], default true, should we show a progress
  #   bar with estimated progress.
  def initialize(show_progress_bar: true)
    @sample = []
    @shrine_storage = ScihistDigicoll::Env.shrine_derivatives_storage

    @s3_iterator = S3PathIterator.new(
      shrine_storage: shrine_storage,
      show_progress_bar: show_progress_bar,
      progress_bar_total: derivative_count
    )
  end

  def derivative_count
    @derivatives_count ||= Asset.all_derivative_count + OralHistoryContent.where.not(combined_audio_fingerprint: nil).count * 2
  end

  # Deletes all found orphans, outputing to console what was deleted.
  # If obj initializer show_progress_bar, there will be a progress bar.
  def delete_orphans
    @delete_count = 0
    s3_iterator.each_s3_path do |s3_path|
      next if IGNORE_PATH_PREFIXES.any? {|p| s3_path.start_with?(p) }
      asset_id, derivative_key, shrine_path = parse_s3_path(s3_path)
      if orphaned?(asset_id, derivative_key, s3_path)
        shrine_storage.delete(s3_path)
        s3_iterator.log "deleted derivative file at: #{bucket_name}: #{s3_path}"
        @delete_count += 1
      end
    end
    output_to_stderr "\nDeleted #{delete_count} orphaned derivatives"
  end

  # Prints out any orphans found, and some summary info. If show_progress_bar was
  # set in an initializer, there will be a progress bar.
  def report_orphans
    max_reports = 40
    @orphans_found = 0
    @files_checked = s3_iterator.each_s3_path do |s3_path|
      next if IGNORE_PATH_PREFIXES.any? {|p| s3_path.start_with?(p) }
      first_part, second_part, shrine_path = parse_s3_path(s3_path)
      if orphaned?(first_part, second_part, shrine_path)
        @orphans_found +=1
        if @orphans_found == max_reports
          s3_iterator.log "Reported max #{max_reports} orphans. Not listing subsequent.\n"
        elsif orphans_found < max_reports
          @sample << s3_url_for_path(s3_path)
          if combined_audio_derivative?(first_part)
            report_orphaned_combined_audio_derivative(second_part, shrine_path, s3_path)
          else
            report_orphaned_derivative(first_part, second_part, shrine_path, s3_path)
          end
          s3_iterator.log ""
        end
      end
    end

    output_to_stderr "\n\nTotal Asset count: #{Asset.count}"
    output_to_stderr "Estimated expected derivative file count: #{derivative_count}"
    output_to_stderr "Checked #{@files_checked} files on S3"
    output_to_stderr "Found #{@orphans_found} orphan files\n"
  end

  private

  def report_orphaned_derivative(asset_id, derivative_key, shrine_path, s3_path)
    asset = Asset.where(id: asset_id).first
    derivative = asset && asset.file(derivative_key.to_sym)

    s3_iterator.log "orphaned derivative!"
    s3_iterator.log "  bucket: #{bucket_name}"
    s3_iterator.log "  s3 path: #{s3_path}"
    s3_iterator.log "  expected shrine id: #{shrine_path}"
    s3_iterator.log "  asset_id: #{asset_id}"
    s3_iterator.log "  derivative_key: #{derivative_key}"
    if asset.nil?
      s3_iterator.log "  asset missing"
    elsif derivative.nil?
      s3_iterator.log "  derivative shrine file missing, #{asset.friendlier_id}"
    else
      s3_iterator.log ""
      s3_iterator.log "  asset friendlier_id: #{asset.friendlier_id}"
      s3_iterator.log "  actual shrine id for #{derivative_key}: #{derivative.storage_key}:#{derivative.id}"
    end
  end

  def report_orphaned_combined_audio_derivative(work_id, shrine_path, s3_path)
    s3_iterator.log "orphaned combined audio derivative!"
    if !(Work.where(id: work_id).present?)
      s3_iterator.log "  Work is missing."
      s3_iterator.log "  bucket: #{bucket_name}"
      s3_iterator.log "  s3 path: #{s3_path}"
    else
      s3_iterator.log "  Work: #{Work.find(work_id).title}: #{shrine_path}"
      s3_iterator.log "  S3 URL: https://s3.console.aws.amazon.com/s3/buckets/#{bucket_name}?prefix=combined_audio_derivatives/#{work_id}"
    end
  end

  def output_to_stderr(text)
    $stderr.puts text
  end

  def bucket_name
    s3_iterator.s3_bucket_name
  end

  def parse_s3_path(s3_path)
    s3_path =~ %r{(([^/]+)/([^/]+)/[^/]+)\Z}

    shrine_path = $1
    asset_pk = $2
    derivative_key = $3

    return [asset_pk, derivative_key, shrine_path]
  end


  def combined_audio_derivative?(first_part_of_s3_path)
    first_part_of_s3_path == 'combined_audio_derivatives'
  end

  # Attempts to looks up the oral history work whose c.a.d this is.
  # If we can't find the work or it's not an oral history: orphan.
  # If it doesn't have an existing derivative in S3 corresponding to the file: orphan.
  def orphaned_combined_audio_derivative?(derivative_key, shrine_path)
    # find the work
    work_id = derivative_key
    work = Work.where(id: work_id).first
    return true unless work.present? && work.is_oral_history?

    deriv = work.oral_history_content!.combined_audio_m4a
    return false if deriv.present? && deriv.url.end_with?(shrine_path)

    # ok, this is an orphaned combined audio deriv.
    true
  end

  def orphaned?(first_part, derivative_key, shrine_path)
    return true unless first_part.present? && derivative_key.present?
    return orphaned_combined_audio_derivative?(derivative_key, shrine_path) if combined_audio_derivative?(first_part)
    ! Kithe::Asset.where(id: first_part).where("file_data -> 'derivatives' -> ? ->> 'id' = ?", derivative_key, shrine_path).exists?
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
