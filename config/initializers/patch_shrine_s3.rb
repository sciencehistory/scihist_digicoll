# Patch to shrine to allow us to do automated S3 tagging via shrine. This is a copy
# of what has been PR'd and merged into shrine already at:
#
#   https://github.com/shrinerb/shrine/pull/569/
#
# So this patch can and should be removed when a version of shrine including it
# is released and we upgrade to it. Presumably shrine 3.5.0

SanePatch.patch('shrine', '3.4.0', details: "this should not be necessary in shrine 3.5.0 if shrine PR #569 is included") do
  require 'shrine/storage/s3'

  class Shrine
    module Storage
      class S3
        # Copies an existing S3 object to a new location. Uses multipart copy for
        # large files.
        def copy(io, id, **copy_options)
          # don't inherit source object metadata or AWS tags
          options = {
            metadata_directive: "REPLACE",
            tagging_directive: "REPLACE"
          }

          if io.size && io.size >= @multipart_threshold[:copy]
            # pass :content_length on multipart copy to avoid an additional HEAD request
            options.merge!(multipart_copy: true, content_length: io.size)
          end

          options.merge!(copy_options)

          object(id).copy_from(io.storage.object(io.id), **options)
        end
      end
    end
  end
end
