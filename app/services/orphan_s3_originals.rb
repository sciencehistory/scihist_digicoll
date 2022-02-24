# Our original files in S3 are stored with keypaths with template:
#
#    ./{model_name}/{uuid_pk}/{random.suffix}
#
# Eg,
#
#    /asset/00968a6c-957a-46a9-817a-a7893aeafed0/0be15a7ad6a89091ad650e498dc5ffb2.jpg
#
# The `./` may be bucket root, or may be at a prefix inside a bucket, depending on
# how our `shrine-store_storage` is configured.
#
# This class will use S3 API to iterate through ALL keys in configured shrine_store_storage,
# for each one try to parse out the UUID-pk from the path, and check the postgres database
# to make sure an Asset with that pk exists, and it is pointing to the found file on S3.
#
# If both those things are not true, it is considered 'orphaned'. This class can be used to
# report on all discovered orphaned files, or to actually _delete_ orphaned files.  This class
# is normally called from a rake task.
class OrphanS3Originals
  attr_reader :s3_iterator, :shrine_storage,  :orphans_found, :delete_count, :sample

  # @param show_progress_bar [Boolean], default true, should we show a progress
  #   bar with estimated progress.
  def initialize(show_progress_bar: true)
    @sample = []
    @iterators = [
      S3PathIterator.new(
        shrine_storage: ScihistDigicoll::Env.shrine_store_storage,
        extra_prefix: 'asset',
        show_progress_bar: show_progress_bar,
        progress_bar_total: asset_count
      ),
      S3PathIterator.new(
        shrine_storage: ScihistDigicoll::Env.shrine_store_video_storage,
        extra_prefix: 'asset',
        show_progress_bar: show_progress_bar,
        progress_bar_total: asset_count
      )
    ]
  end

  # Prints out any orphans found, and some summary info. If show_progress_bar was
  # set in an initializer, there will be a progress bar.
  def report_orphans
    max_reports = 20
    @orphans_found = 0
    files_checked = 0
    @iterators.each do |it|
      prefix = prefix(it.shrine_storage)
      files_checked += it.each_s3_path do |s3_key|
        asset_id, shrine_path = parse_s3_path(s3_key, prefix)
        if orphaned?(asset_id, shrine_path)
          @orphans_found +=1
          if @orphans_found == max_reports
            it.log "Reported max #{max_reports} orphans, not listing subsquent...\n"
          elsif @orphans_found < max_reports
            @sample << s3_url_for_path(s3_key, it.shrine_storage)
            asset = Asset.where(id: asset_id).first
            it.log "orphaned file!"
            it.log "  bucket: #{ it.shrine_storage.bucket.name }"
            it.log "  s3 path: #{s3_key}"
            it.log "  asset_id: #{asset_id}"
            if asset.nil?
              it.log "  asset missing"
            else
              it.log "  asset friendlier_id: #{asset.friendlier_id}"
              it.log "  asset file_data ->> id: #{asset.file_data["id"]}"
            end
            it.log ""
          end
        end
      end
    end

    $stderr.puts "\n\nTotal Asset count: #{asset_count}"
    $stderr.puts "Checked #{files_checked} files on S3"
    $stderr.puts "Found #{@orphans_found} orphan files\n"
  end

  # Deletes all found orphans, outputing to console what was deleted.
  # If obj initializer show_progress_bar, there will be a progress bar.
  def delete_orphans
    @delete_count = 0
    @iterators.each do |it|
      it.each_s3_path do |s3_key|
        asset_id, shrine_path = parse_s3_path(s3_key)
        if orphaned?(asset_id, shrine_path)
          it.shrine_storage.bucket.object(s3_key).delete
          it.log "deleted: #{ it.shrine_storage.bucket.name }: #{s3_key}"
          @delete_count += 1
        end
      end
    end
    puts "Deleted #{@delete_count} orphaned objects"
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
  def parse_s3_path(s3_path, prefix=nil)
    s3_path =~ %r{\A#{prefix}(([^/]+/)([^/]+/).*)\Z}

    _model_name     = $2
    shrine_id_value = $1
    asset_id        = $3 && $3.chomp("/")

    return [asset_id, shrine_id_value]
  end

  def prefix(storage)
    if storage.prefix.nil?
      nil
    else
      Regexp.escape(storage.prefix.chomp('/') + '/')
    end
  end

  # note that the s3_path is complete path on bucket, it might include a prefix
  # from the shrine storage already. We just want a complete good direct to S3 URL
  # as an identifier, it may not be accessible, it wont' use a CDN, etc.
  def s3_url_for_path(s3_path, shrine_storage)
    if shrine_storage.respond_to?(:bucket)
      shrine_storage.bucket.object(s3_path).public_url
    else
      # we aren't S3 at all, not sure what we'll get...
      shrine_storage.url(s3_path)
    end
  end

  def asset_count
    @asset_count ||= Asset.count
  end



end
