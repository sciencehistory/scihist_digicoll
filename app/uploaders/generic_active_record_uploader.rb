# Completely generic no-customization shrine uploader with activerecord, that
# we can use for generic files we don't care that much about.
#
# Also does a good on-storage location based on model name and id.
class GenericActiveRecordUploader < Shrine
  plugin :activerecord
  plugin :pretty_location

  # we don't know if we really care about determining mime type for these,
  # they mostly aren't going to be user-uploaded, but
  # shrine will complain unless we set one.
  plugin :determine_mime_type, analyzer: :marcel
end
