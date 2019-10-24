# Just encapsulates some common functionality for iterating through files on S3,
# with a progress bar. Used by the various orphan file checkers.
#
# @example
#
#     iterator = S3PathIterator.new(bucket)
#     iterator.each_s3_path do |s3_path|
#       iterator.log "We found this S3 path: #{s3_path}"
#     end
#
class S3PathIterator
  attr_reader :shrine_storage, :extra_prefix, :progress_bar, :progress_bar_total


  # @param shrine_storage [Shrine::Storage] the Shrine::Storage indicating an S3 bucket
  #   we're going to list keys off of. It can have a `prefix` set on it, in which case
  #   we'll only iterate within that prefix (although complete keys are still yielded)
  #
  # @param extra_prefix [String] Additional keypath prefix to iterate within, will be
  #   added onto any prefix already built into bucket. eg "foo/bar".
  #
  # @param first_level_only [Boolean] Default false, if true we'll iterate S3 passing
  #   `delimiter: '/'`, meaning we'll only return hiearchically top-level keys, ie files
  #   or "directories" directly at the prefix(es) specified.
  #
  # @param show_progress_bar [Boolean] show a progress bar!
  #
  # @param progress_bar_total [Integer] if using show_progress_bar, pass this in unless you want
  #   an indeterminate 'spinner' progress bar.
  def initialize(shrine_storage:,
                 extra_prefix: nil,
                 first_level_only: false,
                 show_progress_bar: true,
                 progress_bar_total: nil)
    @shrine_storage = shrine_storage
    @extra_prefix = extra_prefix
    @first_level_only = first_level_only

    if show_progress_bar
      @progress_bar =  ProgressBar.create(total: progress_bar_total, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)
      @progress_bar_total = progress_bar_total
    end
  end

  def first_level_only?
    @first_level_only
  end

  # Text you want to send to console.
  #
  # If progress_bar, use progress_bar#log. Otherwise plain old puts. So can be used
  # to log to console without interfering with possibly existing progress bar.
  def log(msg)
    if progress_bar
      progress_bar.log(msg)
    else
      $stderr.puts(msg)
    end
  end

  # The main thing you're going to want to call to get all relevant S3 key paths
  # for bucket/prefix(es) specified. Will also include commonPrefix "directories"
  # at top level if `first_level_only` was set.
  #
  # Implemented in terms of private method _each_s3_path, but adding progress bar
  # functionality, and return value.
  #
  # @return [Integer] total number of entries checked
  def each_s3_path
    files_checked = 0

    _each_s3_path do |s3_key|
      yield(s3_key)

      files_checked += 1
      if progress_bar
        if progress_bar.total && progress_bar.progress + 1 >= progress_bar.total
          # more files than we expected, which makes sense if they were orphans...
          progress_bar.total = nil
        end
        progress_bar.increment
      end
    end

    progress_bar.finish if progress_bar

    return files_checked
  end


  private

  def search_prefix
    @search_prefix ||= [shrine_storage.prefix, extra_prefix, ""].compact.collect {|h| h.sub(/\/\Z/, '') }.join("/")
  end

  def s3_bucket_name
    @s3_bucket_name ||= shrine_storage.bucket.name
  end

  def s3_client
    @s3_client ||= shrine_storage.client
  end

  # iterate through all the keypaths in S3, based on our bucket and extra_prefix, yielding each one to block passed
  # by caller.
  #
  # If first_level_only?, then we apply "delimiter: '/'", meaning AWS will only be iterating over "top-level"
  # hiearchical keys, but we yield terminal keys AND common prefixes (files and "directories") at top level.
  def _each_s3_path
    delimiter = first_level_only? ? "/" : nil

    s3_client.list_objects_v2(bucket: s3_bucket_name, prefix: search_prefix, delimiter: delimiter, max_keys: 1000).each do |s3_response|
      s3_response.common_prefixes.each do |s3_obj|
        yield s3_obj.prefix
      end
      s3_response.contents.each do |s3_obj|
        yield s3_obj.key
      end
    end
  end

end
