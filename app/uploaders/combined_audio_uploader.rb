# Shrine uploader used for our combined audio derivatives in OralHistoryContent
#
# Pretty bare-bones, does set a custom storage location path.
class CombinedAudioUploader < Shrine
    plugin :activerecord

    # File it by work id, include the original filename in the S3 key, but also
    # generated UUID and suffix. Locations on S3 will look something like:
    #
    #     [work_uuid_pk]/combined_[uuid].m4a
    #
    # ie
    #
    #     "9ed358d2-37b9-4cdc-8c3e-bcad4c0aee95/combined_b16f4aa27ec4e7d88fc73c1923ceebfb.m4a"
    def generate_location(io, metadata: {}, **options)
      # assumes we're only used with OralHistoryContent model, that has a work_id
      work_id = options[:record].work_id
      original_uuid = super

      orig_filename = File.basename(metadata["filename"] || "", ".*")
      "#{work_id}/#{orig_filename}_#{original_uuid}"
    end
end
