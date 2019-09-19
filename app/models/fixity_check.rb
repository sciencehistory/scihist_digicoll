
# This is the record of a fixity check.
# See also /app/services/fixity_checker.rb, which has most of the functionality
# relating to creating and pruning fixity checks.

class FixityCheck < ApplicationRecord
  belongs_to :asset
  validates_presence_of :asset

  # Returns in reverse chron order: first is most recent check.
  def self.checks_for(asset, checked_uri)
    FixityCheck.where(asset: asset, checked_uri: checked_uri).order('created_at desc, id desc')
  end

  def failed?
    !passed?
  end

  def passed?
    passed
  end

  # A link to the checked_uri in the AWS S3 Console. Kind of hacky and fragile, will break
  # if AWS changes their console URLs, or if our assumptions weren't quite right in other
  # ways, but it's so clever and useful when it works!
  def checked_uri_in_s3_console
    @checked_uri_in_s3_console ||= begin
      region = ScihistDigicoll::Env.lookup(:aws_region)
      parts = checked_uri_on_s3_components
      if parts
        "https://s3.console.aws.amazon.com/s3/buckets/#{parts[:bucket]}/#{parts[:key_path]}/?region=#{region}&tab=overview&prefixSearch=#{parts[:end_key]}"
      else
        nil
      end
    end
  end

  private

  # returns false if we do not think checked_uri looks like S3.
  # (If we later use a custon CNAME for S3 buckets, may have to adjust this!)
  #
  # returns a hash with keys :bucket, :key_path, :end_path
  # Used for #checked_uri_in_s3_console to link admins directly to a AWS S3 console.
  #
  def checked_uri_on_s3_components
    parsed = URI.parse(checked_uri)

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
