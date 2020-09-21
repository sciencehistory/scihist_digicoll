# Derivatives can be stored in a "restricted" location or a "public" location. If the setting changes
# or they have become out of sync, this job will fix it, moving/copying/deleting derivatives if required,
# to now be in the right place.
#
# Also makes sure no DZI files for assets set to restricted derivatives
class EnsureCorrectDerivativesStorageJob < ApplicationJob

  def perform(asset)
    ensure_correct_derivative_locations(asset)

    if asset.derivative_storage_type == "restricted"
      # no dzi files supported for restricted derivatives, as DZI storage is not secure!
      asset.dzi_file.delete
    end
  end

  private


  # routine to copy derivatives to current proper storage location modified from:
  # https://shrinerb.com/docs/changing-location
  def ensure_correct_derivative_locations(asset)
    if asset.derivatives_in_correct_storage_location?
      Rails.logger.debug("#{self.class.name}: All derivatives for #{asset.friendlier_id }already in proper storage type #{asset.derivative_storage_type}, no need to move")
      return
    end

    attacher = asset.file_attacher
    old_attacher = attacher.dup

    # reupload all derivatives, they will wind up in appropriate location
    # even if they weren't before.
    attacher.set_derivatives attacher.upload_derivatives(attacher.derivatives)

    begin
      attacher.atomic_persist           # persist changes if attachment has not changed in the meantime
      old_attacher.delete_derivatives   # delete old derivatives now re-uploaded
    rescue Shrine::AttachmentChanged,   # attachment has changed during reuploading
           ActiveRecord::RecordNotFound # record has been deleted during reuploadin

      # delete the derivatives we re-uploaded, cause they didn't end up
      # attacched and no longer apply
      attacher.delete_derivatives
    end
  end
end
