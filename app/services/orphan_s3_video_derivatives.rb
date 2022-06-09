# This service class looks at all the files in the s3 directory where we store our
# video derivatives and links each one to a current video original.  It can either report
# a list of "orphans", or delete them.
#
# We anticipate having video derivatives numbering in the thousands (not in the millions as with DZI tiles)
# and all the derivatives are at the same level in the s3 folder hierarchy. Because of this it's realistic
# to at least start out looking at all the video derivatives.
#
# We can certainly decide to be less exhaustive if in a year or two we find we have a
# lot more video derivs than we expected.

# bundle exec rails runner 'OrphanS3VideoDerivatives.new(show_progress_bar: false).report_orphans'

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
    $stderr.puts "Iterated through #{files_checked} video derivatives on S3"
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

  # Given an actual S3 path, return:
  # 1) the shrine_id, such that 
  #    shrine_storage.object(shrine_id).exists? returns true (and thus we can delete the file if we want)
  # 2) the asset_id of the video whose deriv this is supposed to be
  # 3) an md5 which is not the md5 of the video, but which we *can* use in #orphaned? to link the
  #     asset to the derivative.
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
  #    shrine_id       = "hls/0eadfd9b-c36b-4b02-a5e1-63a00a259410/2160f6d44ed781f81e7a4a66d5a0b117/hls_extra_low_00001.ts"
  # Note that the md5 is NOT the hash of the asset, but can still be used to confirm the association
  # between the derivative and the asset.
  def parse_s3_path(s3_path)
    shrine_id =  remove_prefix(s3_path)
    dir_name, asset_id, md5, deriv_filename = shrine_id.split('/')
    # dir_name is always going to be "hls"; discard.
    return [asset_id, md5, shrine_id]
  end


  # We're not interested in the storage_prefix. What we want is what
  # shrine thinks of as the path on S3, and our way of accessing
  # and deleting the file if we determine it to be orphaned.
  def remove_prefix(s3_path)
    return s3_path if shrine_storage.prefix.nil?
    s3_path.delete_prefix(shrine_storage.prefix + "/")
  end

  # See infrastructure/aws-mediaconvert/README.md for more details
  # (including links to GitHub and the wiki) about
  # what goes in json_attributes->'hls_playlist_file_data'.
  #
  # Note also that because the innermost hash is escaped and
  # stored as a string, we need to extract the filepath using a trick described at 
  #     https://dev.to/mrmurphy/so-you-put-an-escaped-string-into-a-json-column-2n67.
  #
  # Easy improvement:
  # for all video assets, fetch their asset_id and hls_playlist_file_data in a single
  # database query and store them in memory rather than querying the database for *each* derivative.
  def orphaned?(asset_id, md5)
    unless asset_id && md5
       return true
    end
    ! Asset.where(id: asset_id).where("(json_attributes->'hls_playlist_file_data' #>> '{}')::jsonb->>'id' = ?", "hls/#{asset_id}/#{md5}/hls.m3u8" ).exists?
  end


  # An approximation of a legitimate HLS derivative filepath.
  # We can adjust it as needed but it should work fine for our current purposes.
  #
  # Exactly four directories in the path,
  # the first named hls,
  # followed by a filename starting in hls
  # and ending in either .ts or .m3u8 .
  def legitimate_hls_derivative?(s3_path)
    /hls\/[^\/]*\/[^\/]*\/hls[^\/]*\.(ts|m3u8)$/.match(s3_path)
  end


  # Note that the s3_path is the complete path on bucket. This might include a prefix
  # from the shrine storage already. For our report in the admin pages,
  # we just want a functioning URL that takes us directly to S3 if we need to investigate.
  def s3_url_for_path(s3_path)
    if shrine_storage.respond_to?(:bucket)
      shrine_storage.bucket.object(s3_path).public_url
    else
      shrine_storage.url(s3_path)
    end
  end
end