require 'shrine'
require "shrine/storage/file_system"


# Used for "direct uploads" from Javascript in form, sending them to OUR APP
# (rather than direct to S3)
Shrine.plugin :upload_endpoint

# For now we're using local file storage, NOT what we'll want in production.
# Putting it in ./tmp/shrine_storage_testing so we don't forget this isn't done.
Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new("tmp/shrine_storage_testing", prefix: "cache"), # temporary
  store: Shrine::Storage::FileSystem.new("tmp/shrine_storage_testing", prefix: "store"),       # permanent
}
