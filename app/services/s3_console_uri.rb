# S3ConsoleUri.new(asset.file.url(public: true)).console_uri
# S3ConsoleUri.new(some_uri).console_uri
#
#
# This will return a link that takes admins
# directly to a AWS S3 console containing the file
# and various s3 bells and whistles.
# Initially written as part of the fixity checking code,
# but useful in other contexts as well.
class S3ConsoleUri

  # Kind of hacky and fragile, will break
  # if AWS changes their console URLs, or if our
  # assumptions weren't quite right in other ways.
  def console_uri
    @checked_uri_in_s3_console ||= begin
      region = ScihistDigicoll::Env.lookup(:aws_region)
      parts = uri_components
      if parts
        "https://s3.console.aws.amazon.com/s3/buckets/#{parts[:bucket]}/#{parts[:key_path]}/?region=#{region}&tab=overview&prefixSearch=#{parts[:end_key]}"
      else
        nil
      end
    end
  end

  def initialize(uri)
    raise ArgumentError.new("Please pass in a public S3 URI.") if uri.nil?
    @uri = uri
  end

  # returns false if we do not think @uri looks like S3.
  # returns a hash with keys :bucket, :key_path, :end_path
  #
  # If we later use a custom CNAME for S3 buckets,
  # may have to adjust this, it assumes
  # it can recognize S3 as *.s3.amazonaws.com)
  def uri_components
    parsed = URI.parse(@uri)

    return false unless parsed.host

    host_parts = parsed.host.split(".")
    if host_parts.slice(1, host_parts.length) != %w{s3 amazonaws com}
      return false
    end

    path_components = parsed.path.split("/")
    key_path = path_components.slice(1, path_components.length - 2)&.join("/")
    end_key = path_components.last

    {
      bucket: host_parts.first,
      key_path: key_path,
      end_key: end_key
    }
  rescue URI::InvalidURIError
    false
  end
end