class OrphanS3RestrictedDerivatives
  # We put some other things on the 'derivatives' s3, that we want to ignore and not consider orphaned
  IGNORE_PATH_PREFIXES = ["__sitemaps/"]

  attr_reader :s3_iterator, :shrine_storage, :files_checked, :orphans_found, :delete_count

  # @param show_progress_bar [Boolean], default true, should we show a progress
  #   bar with estimated progress.
  def initialize(show_progress_bar: true)
    @shrine_storage = ScihistDigicoll::Env.shrine_store_storage

    @s3_iterator = S3PathIterator.new(
      shrine_storage: shrine_storage,
      extra_prefix: 'restricted_derivatives',
      show_progress_bar: show_progress_bar,
      progress_bar_total: derivative_count
    )
  end

  # TODO: estimate number of restricted derivs.
  def derivative_count
    1
    # @derivatives_count ||= Asset.all_derivative_count
  end

  # Deletes all found orphans, outputing to console what was deleted.
  # If obj initializer show_progress_bar, there will be a progress bar.
  def delete_orphans
    @delete_count = 0
    s3_iterator.each_s3_path do |s3_path|
      next if IGNORE_PATH_PREFIXES.any? {|p| s3_path.start_with?(p) }

      asset_id, derivative_key, shrine_path = parse_s3_path(s3_path)

      if shrine_path && orphaned?(asset_id, derivative_key, shrine_path)
        shrine_storage.delete(shrine_path)
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
          report_orphaned_derivative(first_part, second_part, shrine_path, s3_path)
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
    #puts asset_id#

    #goat = Asset.where(id: '0001d800-482d-4dcf-80b7-84f273580a13').first
    #puts "goat id ", goat.id
    #puts "goat id is asset id", goat.id == asset_id
    #puts "goat is nil", goat.nil?
    #puts "asset is nil", asset.nil?

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
    exit
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

  def orphaned?(first_part, derivative_key, shrine_path)
    return true unless first_part.present? && derivative_key.present?
    ! Kithe::Asset.where(id: first_part).where("file_data -> 'derivatives' -> ? ->> 'id' = ?", derivative_key, shrine_path).exists?
  end
end