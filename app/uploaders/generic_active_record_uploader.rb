# Completely generic no-customization shrine uploader with activerecord, that
# we can use for generic files we don't care that much about.
#
# Also does a good on-storage location based on model name and id.
class GenericActiveRecordUploader < Shrine
  plugin :activerecord
  plugin :pretty_location
end
