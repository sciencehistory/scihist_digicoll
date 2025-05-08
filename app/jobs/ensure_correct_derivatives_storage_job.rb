# Derivatives can be stored in a "restricted" location or a "public" location. If the setting changes
# or they have become out of sync, this job will fix it, moving/copying/deleting derivatives if required,
# to now be in the right place.
#
# Also makes sure no DZI files for assets set to restricted derivatives
class EnsureCorrectDerivativesStorageJob < ApplicationJob

  def perform(asset)
    ensure_correct_derivative_locations(asset)
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

      # and if we've been succesful, remove DZI files, all versions, and all
      # backup bucket versions...
      if asset.derivative_storage_type == "restricted"
        remove_all_public_ancillary_files_and_versions(asset)
      end
    rescue Shrine::AttachmentChanged,   # attachment has changed during reuploading
           ActiveRecord::RecordNotFound # record has been deleted during reuploadin

      # delete the derivatives we re-uploaded, cause they didn't end up
      # attacched and no longer apply
      attacher.delete_derivatives
    end
  end

  # If we have moved the file to `restricted` storage, we have a bunch of ancillary
  # files that need to be deleted too!
  #
  #  * previous S3 'versions' on public derivatives bucket
  #  * all versions on derivatives BACKUP bucket
  #  * DZI files (we don't support restricted DZI files), including all versions
  #  * all versions from DZI BACKUP bucket!
  #
  # Phew! WARNING In order to do this efficiently, we have t make some
  # assumptions about where derivatives are stored, we assume they are stored under
  # the Asset UUID PK prefix directly on buckets. If we change our design
  # to store in a different place later, this runs the risk of silently failing
  # to delete actual versions and files.
  #
  # Also assumes buckets ARE versioned, unclear if it will work properly
  # otherwise.
  #
  # This is a bit hacky/fragile code, but best we could do for now.
  def remove_all_public_ancillary_files_and_versions(asset)
    # Where we assume derivatives are located for this asset...
    derivative_prefix = [Shrine.storages[:kithe_derivatives].prefix, "#{asset.id}/"].compact.join("/")
    dzi_prefix        = [Shrine.storages[:dzi_storage].prefix, "#{asset.id}/"].compact.join("/")

    # remove all past versions from live derivatives bucket IF S3 (expected in production, not staging/dev/test)
    if Shrine.storages[:kithe_derivatives].kind_of?(Shrine::Storage::S3)
      Shrine.storages[:kithe_derivatives].bucket.object_versions(prefix: derivative_prefix).batch_delete!
    end

    # remove DZI file in the normal more reliable way, regardless of storage type
    if asset.dzi_package
      asset.dzi_package.delete
    end

    # remove all versions of all DZI files from main DZI location IF on S3 (expected in production, not staging/dev/test)
    if Shrine.storages[:dzi_storage].kind_of?(Shrine::Storage::S3)
      Shrine.storages[:dzi_storage].bucket.object_versions(prefix: dzi_prefix).batch_delete!
    end

    # Backup bucket calls will raise if we are on production and can't find it, to be extra careful!

    # remove all versions from derivatives backup bucket if we have one
    if backup_bucket = ScihistDigicoll::Env.derivatives_backup_bucket
      backup_bucket.object_versions(prefix: derivative_prefix).batch_delete!
    elsif ScihistDigicoll::Env.production?
      raise RuntimeError.new("In production tier, but missing derivatives backup bucket settings presumed to exist")
    end

    # remove all versions from dzi backup bucket if we have one
    if dzi_backup_bucket = ScihistDigicoll::Env.dzi_backup_bucket
      dzi_backup_bucket.object_versions(prefix: dzi_prefix).batch_delete!
    elsif ScihistDigicoll::Env.production?
      raise RuntimeError.new("In production tier, but missing derivatives backup bucket settings presumed to exist")
    end
  end
end
