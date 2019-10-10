class S3PathIterator
  attr_reader :shrine_storage, :extra_prefix, :progress_bar, :progress_bar_total

  # progress_bar_total can be just estimated, that's all we usually have available.
  def initialize(shrine_storage:,
                 extra_prefix: nil,
                 check_base_paths_only: false,
                 show_progress_bar: true,
                 progress_bar_total: nil)
    @shrine_storage = shrine_storage
    @extra_prefix = extra_prefix
    @check_base_paths_only = check_base_paths_only

    if show_progress_bar
      @progress_bar =  ProgressBar.create(total: progress_bar_total, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)
      @progress_bar_total = progress_bar_total
    end
  end

  def check_base_paths_only?
    @check_base_paths_only
  end

  # If progress_bar, use progress_bar#log. Otherwise plain old puts. Caller will want to
  # use to not interfere with progress bar.
  def log(msg)
    if progress_bar
      progress_bar.log(msg)
    else
      $stderr.puts(msg)
    end
  end

  # _each_s3_path with progress bar apparatus and return report added
  #
  # Returns an OpenStruct with total number of S3 files checked, total number of assets, etc.
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

    return OpenStruct.new(
      files_checked: files_checked,
    )
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
  # If check_base_paths_only?, then instead of yielding each path, we only yield the top-level component of the path
  # after the bucket prefix and extra_prefix -- the component that should be the pk UUID.
  def _each_s3_path
    delimiter = check_base_paths_only? ? "/" : nil

    s3_client.list_objects_v2(bucket: s3_bucket_name, prefix: search_prefix, delimiter: delimiter, max_keys: 1000).each do |s3_response|
      if delimiter
        s3_response.common_prefixes.each do |s3_obj|
          yield s3_obj.prefix
        end
      else
        s3_response.contents.each do |s3_obj|
          yield s3_obj.key
        end
      end
    end
  end

end
