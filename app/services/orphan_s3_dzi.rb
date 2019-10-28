# DZI files (https://en.wikipedia.org/wiki/Deep_Zoom) are stored on S3 using
# a keypath template:
#
#     ./{asset uuid}/{md5 hash}.dzi
#     ./{asset uuid}/{md5 hash}_files/{lots of tiles}
#
# The `x.dzi` manifest file corresponding to an `x_files` directory full of
# hieararchical tiles, is part of the DZI format.
#
# This class will use S3 API to iterate through all files found on an S3 bucket, looking
# for .dzi files to check.  In order to do that, it actually needs to do two sets of iteration --
# first iterating through the top level to find all `{uuid}` directories, then for each one,
# iterating through it's contents to find ".dzi" files.
#
# For each .dzi file found,it'll check to make sure an asset with the UUID encoded in path exists,
# and it has the MD5 encoded in path -- if not, the `x.dzi` file (and all of it's corresponding tiles)
# are "orphaned", and no longer correspond to an existing asset, and should be deleted.
# This class can also delete them.
#
# The checker ONLY checks `.dzi` files, and if it finds an "orphan" deletes the .dzi file and
# it's associated `_files` "folder". It will not even check other files that don't even end
# in .dzi.
#
# The double/nested iteration required to find all .dzi files using available S3 API and when
# they are ararnged as they are, when run over our current ~25K .dzi files, takes around
# 12 minutes to run on our EC2 instances, and costs around 12 cents every time you run it.
# The time and cost could be reduced significantly if we reorganized the keypath arrangement.
#
# We could consider switching to a layout more like chf_sufia used, where there isn't
# an `{asset uuid}/` component in the path, but all .dzi files and _files folders
# are siblings next to each other, and the asset uuid is encoded directly in the .dzi/_files name.
# It turns out that makes it much more convenient to more quickly find just the top-level .dzi
# files, using the S3 'delimiter' API. And allows report/delete in more like 5 minutes. But
# would require a reorganization of our many gigs of DZI files, which is hard to do on S3.
class OrphanS3Dzi

  attr_reader :s3_iterator, :shrine_storage, :show_progress_bar
  def initialize(show_progress_bar: true)
    @shrine_storage = ScihistDigicoll::Env.shrine_dzi_storage
    @show_progress_bar = show_progress_bar

    @s3_iterator = S3PathIterator.new(
      shrine_storage: shrine_storage,
      show_progress_bar: show_progress_bar,
      progress_bar_total: asset_count,
      first_level_only: true
    )
  end

  def asset_count
    @asset_count ||= Asset.count
  end

  def delete_orphans
    delete_count = 0
    find_orphan_dzi_files do |asset_id:, md5:, shrine_id:, s3_path:|
      # delete .dzi file
      shrine_storage.delete(shrine_id)
      # delete all tiles using shrine storage delete_prefixed
      shrine_storage.delete_prefixed(shrine_id.sub(".dzi", "_files/"))
      s3_iterator.log "deleted all DZI tiles for: #{shrine_storage.bucket.name}: #{s3_path}"
      delete_count += 1
    end
    $stderr.puts "\nDeleted #{delete_count} sets of orphaned derivatives"
  end

  def report_orphans
    max_reports = 20
    orphans_found = 0

    files_checked = find_orphan_dzi_files do |asset_id:, md5:, shrine_id:, s3_path:|
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

    $stderr.puts "\n\nTotal Asset count: #{asset_count}"
    $stderr.puts "Iterated through #{files_checked} tile files on S3"
    $stderr.puts "Found #{orphans_found} orphan files\n"
  end

  private

  # re-used by both report and delete, since we have a bit of non-standard
  # non-trivial logic. Will yield to block (asset_id, md5, shrine_id, s3_path) for each x.dzi file found
  # determined to be an orphan. Will return number of files checked.
  #
  # @yield [asset_id:, md5:, shrine_id:, s3_path:]
  def find_orphan_dzi_files
    s3_iterator.each_s3_path do |top_s3_path|
      # we have a "directory" for an asset, now we need to check that directory with
      # another request.
      sub_iterator = S3PathIterator.new(
        shrine_storage: shrine_storage,
        extra_prefix: top_s3_path.split("/").last,
        show_progress_bar: false,
        progress_bar_total: asset_count,
        first_level_only: true
      )
      sub_iterator.each_s3_path do |s3_path|
        # We only care about .dzi manifests, we're not gonna check every tile
        next unless s3_path.end_with?(".dzi")

        asset_id, md5, shrine_id = parse_s3_path(s3_path)

        if orphaned?(asset_id, md5)
          yield asset_id: asset_id, md5: md5, shrine_id: shrine_id, s3_path: s3_path
        end
      end
    end
  end

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
