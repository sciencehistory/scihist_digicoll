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
  attr_reader :video_s3_iterator, :nonvideo_s3_iterator, :shrine_storage,  :orphans_found, :files_checked, :delete_count, :sample

  # @param show_progress_bar [Boolean], default true, should we show a progress
  #   bar with estimated progress.
  def initialize(show_progress_bar: true)
    
    @nonvideo_asset_count = counts['store']
    @video_asset_count     = counts['video_store']

    @video_s3_iterator = S3PathIterator.new(
        shrine_storage: ScihistDigicoll::Env.shrine_store_video_storage,
        extra_prefix: 'asset',
        show_progress_bar: show_progress_bar,
        progress_bar_total: @video_asset_count
    )

    @nonvideo_s3_iterator = S3PathIterator.new(
        shrine_storage: ScihistDigicoll::Env.shrine_store_storage,  
        extra_prefix: 'asset',
        show_progress_bar: show_progress_bar,
        progress_bar_total: @nonvideo_asset_count
    )
    
    @iterators = [@video_s3_iterator, @nonvideo_s3_iterator]
    @sample = []
  end


  # Prints out any orphans found, and some summary info. If show_progress_bar was
  # set in an initializer, there will be a progress bar.
  def report_orphans
    max_reports = 20
    @orphans_found = 0
    @files_checked = 0
    @iterators.each do |iter|
      prefix = prefix(iter.shrine_storage)
      bucket_name = bucket_name(iter.shrine_storage)
      @files_checked += iter.each_s3_path do |s3_key|
        asset_id, shrine_path = parse_s3_path(s3_key, prefix)
        if orphaned?(asset_id, shrine_path)
          @orphans_found +=1
          if @orphans_found == max_reports
            iter.log "Reported max #{max_reports} orphans, not listing subsquent...\n"
          elsif @orphans_found < max_reports
            @sample << url_or_path(s3_key, iter.shrine_storage)
            asset = Asset.where(id: asset_id).first
            iter.log "orphaned file!"
            iter.log "  bucket: #{ bucket_name }"
            iter.log "  s3 path: #{s3_key}"
            iter.log "  asset_id: #{asset_id}"
            if asset.nil?
              iter.log "  asset missing"
            else
              iter.log "  asset friendlier_id: #{asset.friendlier_id}"
              iter.log "  asset file_data ->> id: #{asset.file_data["id"]}"
            end
            iter.log ""
          end
        end
      end
    end

    output_to_stderr "\n\nAsset count: #{@video_asset_count} video and #{@nonvideo_asset_count} non-video assets"
    output_to_stderr "Checked #{files_checked} files on S3"
    output_to_stderr "Found #{@orphans_found} orphan files\n"
  end

  # Deletes all found orphans, outputting to console what was deleted.
  # If obj initializer show_progress_bar, there will be a progress bar.
  def delete_orphans
    @delete_count = 0
    @iterators.each do |iter|
      bucket_name = bucket_name(iter.shrine_storage)
      prefix = prefix(iter.shrine_storage)
      iter.each_s3_path do |s3_key|
        asset_id, shrine_path = parse_s3_path(s3_key, prefix)
        if orphaned?(asset_id, shrine_path)
          iter.shrine_storage.delete(shrine_path)
          iter.log "deleted: #{ bucket_name }: #{shrine_path}"
          @delete_count += 1
        end
      end
    end
    output_to_stderr "Deleted #{@delete_count} orphaned objects"
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

  # We start with an actual S3 path.
  # We want to ignore the storage_prefix. What remains is shrine_id_value, 
  # which is what shrine thinks of as the path on S3.
  #
  # In other words, shrine_storage.object(shrine_id_value).exists? should always return true.
  #
  # The path also contains the UUID pk of the Asset whose file (if it's not orphaned)
  # we would expect to find at shrine_storage.object(shrine_id_value) .
  #
  # For example, given:
  # @s3_path = "laptop.local/originals/asset/3d437358-702e-44b1-9a3d-048db01166cf/9dfb96cbe898f8619238de81528c6660.tif"
  # prefix   = "laptop.local/originals/"
  #
  # we get:
  #    _model_name     = "asset/"
  #    shrine_id_value = "asset/3d437358-702e-44b1-9a3d-048db01166cf/9dfb96cbe898f8619238de81528c6660.tif"        
  #    asset_id        = "3d437358-702e-44b1-9a3d-048db01166cf"
  def parse_s3_path(s3_path, prefix=nil)
    s3_path =~ %r{\A#{prefix}(([^/]+/)([^/]+/).*)\Z}
    shrine_id_value = $1
    _model_name     = $2
    asset_id        = $3 && $3.chomp("/")
    return [asset_id, shrine_id_value]
  end

  def prefix(storage)
    if storage.prefix.nil?
      nil
    else
      Regexp.escape(storage.prefix.to_s.chomp('/') + '/')
    end
  end

  def bucket_name(storage)
    if storage.respond_to?(:bucket)
      storage.bucket.name
    else
      storage.directory.to_s
    end
  end

  # note that the s3_path is complete path on bucket, it might include a prefix
  # from the shrine storage already. We just want a complete good direct to S3 URL
  # as an identifier, it may not be accessible, it won't use a CDN, etc.
  def s3_url_for_path(s3_path, shrine_storage)
    if shrine_storage.respond_to?(:bucket)
      shrine_storage.bucket.object(s3_path).public_url
    else
      shrine_storage.url(s3_path)
    end
  end

  def counts
     @counts ||= Kithe::Asset.connection.select_all("select file_data ->> 'storage' as storage, count(*)  from kithe_models where kithe_model_type = 2 group by storage").rows.to_h
  end

  def output_to_stderr(text)
    $stderr.puts text
  end

  def url_or_path(s3_key, storage)
    if storage.is_a? Shrine::Storage::FileSystem
      s3_key
    else
      s3_url_for_path(s3_key, storage)
    end
  end

end
