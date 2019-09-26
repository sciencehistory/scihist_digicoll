require 'shrine/storage/s3'
require 'shrine/storage/file_system'

# Patching in behavior that should be added by shrine 3.0.
# We need it for cleaning up DZI tiles.
#
# https://github.com/shrinerb/shrine/pull/413
SanePatch.patch('shrine', '~> 2.0', details: "Patching in delete_prefixed, which should be there already in shrine 3.0") do
  Shrine::Storage::S3.include(Module.new do
    # Delete files at keys starting with the prefix.
    #
    #    s3.delete_prefixed("somekey/derivatives/")
    def delete_prefixed(delete_prefix)
      # We need to make sure to combine with storage prefix, and
      # that it ends in '/' cause S3 can be squirrely about matching interior.
      normalized_prefix = [*prefix, delete_prefix.chomp("/"), ""].join("/")
      bucket.objects(prefix: normalized_prefix).batch_delete!
    end
  end)

  Shrine::Storage::FileSystem.include(Module.new do
    # Delete files at keys starting with the prefix.
    #
    #    file_system.delete_prefixed("somekey/derivatives/")
    def delete_prefixed(delete_prefix)
      FileUtils.rm_rf(directory.join(delete_prefix).to_s)
    end
  end)
end
