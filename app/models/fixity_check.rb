
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
      original_storage = Shrine.storages[:store]
      uri = URI.parse(checked_uri)

      if original_storage.kind_of?(Shrine::Storage::S3)
        region = ScihistDigicoll::Env.lookup(:aws_region)
        bucket = original_storage.bucket.name
        path_components = uri.path.split("/")
        key_path = path_components.slice(1, path_components.length - 2)&.join("/")
        end_key = path_components.last

        "https://s3.console.aws.amazon.com/s3/buckets/#{bucket}/#{key_path}/?region=#{region}&tab=overview&prefixSearch=#{end_key}"
      else
        # Can't do it, sorry
        nil
      end
    rescue URI::InvalidURIError
      nil
    end
  end
end
