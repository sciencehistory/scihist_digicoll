# A shrine uploader we use to define the attachment on Asset for
# the HLS master playlist (.m3u8) file.
#
# A couple unusual things about it:
#
# * We don't intend to use shrine to upload these files: we have MediaConvert
# place them in an S3 bucket we use as shrine storage, and then just set the
# existing location. (See Asset#hls_playlist_file_as_s3=)
#
# * We provide an inline plugin such that when we shrine deletes the master
# playlist, we delete the entire DIRECTORY it's in, to get the whole HLS
# file set.
#
# * Deletion of HLS derivatives is "backgrounded" to a bg ActiveJob, using standard shrine
#   functionality. we don't use the possibly ill-advised fancy kithe stuff
#   for making that configurable on the fly, it's always backgrounded.
class VideoHlsUploader < Shrine
  plugin :activerecord

  # We aren't intending to use this for handling uploads at all, but if
  # we do, don't use a "cache" storage phase.
  plugin :model, cache: false

  plugin :backgrounding
  Attacher.destroy_block do
    # We can re-use Kithe::AssetDeleteJob, it's re-usable and generic
    Kithe::AssetDeleteJob.perform_later(self.class.name, data)
  end

  class DeleteContainingDirectoryShrinePlugin
    module AttacherMethods
      # Note also ActiveEncodeStatus#clean_up_leftover_files,
      # which destroys HLS files when the original asset is missing,
      # based on ActiveEncodeStatus info in the database.
      # ActiveEncodeStatus#clean_up_leftover_files is called from a
      # scheduled job, meant to run several times a day.
      def destroy
        # delete whole containing directory, not just the referenced file
        containing_directory = File.dirname(file.id)
        file.storage.delete_prefixed(containing_directory)
      end
    end
  end

  plugin DeleteContainingDirectoryShrinePlugin
end
