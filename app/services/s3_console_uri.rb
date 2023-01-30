# Generates a URL to AWS console to look at a file in S3. Currently
# will send you to parent directory, with a search for file.
#
# If we can't find an S3 bucket to use, will silently return a nil url!
#
#     S3ConsoleUri.new(bucket: "bucket-name", keypath: "something/file.jpg")
#
# You can instead send a http/https URI, but it needs to have the bucket
# identifable from *.s3.amazonaws.com hostname -- it won't work if it's using
# cloudfront or other CDN hostname.
#
#     S3ConsoleUri.from_uri(asset.file.url(public: true)).console_uri
#     S3ConsoleUri.from_uri(some_uri).console_uri
#
# Can also take an s3:// url, which is in fact really more reliable.
#
#     S3ConsoleUri.new("s3://bucket-name/path/to/file").console_uri
#
# You can also send a shrine UploadedFile object, using an S3 storage:
#
#     S3ConsoleUri.from_shrine_uploaded_file(some_model.some_file).console_uri
#
class S3ConsoleUri
  attr_reader :bucket, :keypath

  # if bucket is nil, we will not be able to generate URLs.
  def initialize(bucket:, keypath:)
    @bucket = bucket
    @keypath = keypath
  end

  # can we even produce one? if this returns false,
  # then #console_uri will be nil.
  def has_console_uri?
    !! (bucket && keypath)
  end

  # Kind of hacky and fragile attempt to link directly to S3 console.
  #
  # If we have a nil bucket name (couldn't find S3 bucket), will silently
  # return nil.
  def console_uri
    @checked_uri_in_s3_console ||= begin
      if has_console_uri?
        region = ScihistDigicoll::Env.lookup(:aws_region)
        key_path_components = keypath.delete_prefix("/").split("/")
        end_key = key_path_components.last

        # Don't need prefixSearch URL parameter for a folder at the top of the bucket (only occurs in the case of a folder of orphaned DZI files.)
        if key_path_components.count > 1
          base_key_path = key_path_components.slice(0, key_path_components.length - 1)&.join("/").chomp("/").concat("/")
          "https://s3.console.aws.amazon.com/s3/buckets/#{bucket}?region=#{region}&prefix=#{base_key_path}&prefixSearch=#{end_key}"
        else
          "https://s3.console.aws.amazon.com/s3/buckets/#{bucket}?region=#{region}&prefixSearch=#{end_key}"
        end
      else
        nil
      end
    end
  end

  # Could be a public http(s): uri with standard AWS bucket address we can
  # detect, or an s3:// uri
  #
  # If an http(s) URI, needs to be *.s3.amazonaws.com to have identifiable
  # bucket! This will not work if it's a CDN url etc, and is soft-deprecated.
  # Better to use an s3:// URI, or a shrine UploadedFile object in
  # .from_shrine_uploaded_file below.
  def self.from_uri(uri)
    raise ArgumentError.new("Please pass in an S3 URI.") if uri.nil?
    components = uri_components(uri)

    new(bucket: components[:bucket], keypath: components[:keypath])
  end

  # A Shrine::UploadedFile, for instance from a shrine attachment or
  # derivative method.
  #
  # If storage doesn't look like S3, may return a nil bucket.
  def self.from_shrine_uploaded_file(uploaded_file)
    storage = uploaded_file.storage
    bucket = storage && storage.respond_to?(:bucket) && storage.bucket.name

    if storage.respond_to?(:prefix)
      keypath = File.join(storage.prefix.to_s, uploaded_file.id)
    else
      keypath = uploaded_file.id
    end

    new(bucket: bucket, keypath: keypath)
  end


  private


  # returns a hash with keys :bucket, :key_path, :end_path
  #
  # If we can't find all parts, hash may be missing some or all keys. This
  # includes if it has a host that isn't identifiable as *.s3.amazonaws.com --
  def self.uri_components(uri)
    parsed = URI.parse(uri)
    keypath = parsed.path.delete_prefix("/")

    host_parts = parsed.host.present? && parsed.host.split(".")
    if !host_parts || (host_parts.length > 1 && host_parts.slice(1, host_parts.length) != %w{s3 amazonaws com})
      # we don't have a host, or don't have one that has an identifiable S3 bucket
      return { keypath: keypath }
    end

    {
      bucket: host_parts.first,
      keypath: keypath

    }
  rescue URI::InvalidURIError
    {}
  end
end
