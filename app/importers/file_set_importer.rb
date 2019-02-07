require "shrine"
require "shrine/storage/file_system"
require "down"

class FileSetImporter < Importer

  # Load Fedora credentials (only once) into a
  # class variable, if we have them.
  if ENV['FEDORA_USERNAME'].nil? || ENV['FEDORA_PASSWORD'].nil?
    @@fedora_credentials = {}
  else
    @@fedora_credentials ||= {username: ENV['FEDORA_USERNAME'], password: ENV['FEDORA_PASSWORD']}
  end

  def initialize(path, options = {})
    super
    if Rails.env.development?
      @seconds_to_wait_after_importing = 0
    else
      @seconds_to_wait_after_importing = 0
    end
  end

  # If we know the username and password for Fedora,
  # add them to the file URL. The admin user can download
  # originals from Fedora even if they're marked private.
  def edit_metadata()
    if @@fedora_credentials != {}
      basic_download_url = @metadata['file_url']
      credentials = "http://#{@@fedora_credentials[:username]}:#{@@fedora_credentials[:password]}@"
      @metadata['file_url'] = basic_download_url.sub('http://', credentials)
    end
  end

  # Ingesting Assets is by far the most expensive
  # operation in the import sequence, since they need to be
  # retrieved from Fedora and their derivatives need to be generated.
  # This method figures out whetther this Asset has already been ingested.
  # It looks up the preexisting_item based on its friendlier_id,
  # then, if it exists, checks its sha1 hash against what Fedora
  # reported for the original FileSet.
  def ok_to_skip_this_item()
    return false if preexisting_item.nil?
    if preexisting_item.sha1 == @metadata['sha_1']
      puts "The checksums matched; ok to skip this item."
      @seconds_to_wait_after_importing = 0
      return true
    end
    false
  end

  # TODO: this class needs to implement
  # remove_stale_item for the cases in which a prior Asset
  # ingest fails and the resulting file has the wrong checksum.
  # Not a common case but it could happen.


  # How many seconds this returns could depend on
  # whether this item was already skipped; see ok_to_skip_this_item().
  def how_long_to_sleep()
    @seconds_to_wait_after_importing
  end

  # Assets actually have minimal metadata, so this method basically
  # fetches the file from Fedora and (possibly) generates the derivatives.
  def populate()
    # Note: @new_item is an unsaved Asset
    # This tells @new_item's shrine uploader to do promotion inline instead of
    # kicking off a background job.
    @new_item.file_attacher.set_promotion_directives(promote: "inline")
    # Now the promotion is happening inline (not in a bg job), but the promotion will ordinarily
    # kick off yet another job for derivatives creation.
    # We can either tell it NOT to do derivatives creation at all.
    # @new_item.file_attacher.set_promotion_directives(create_derivatives: false)
    # or we can tell it to create derivatives inline:
    @new_item.file_attacher.set_promotion_directives(create_derivatives: "inline")
    @new_item.file = { "id" => metadata['file_url'], "storage" => "remote_url"}
    super
  end

  def self.importee()
    return 'FileSet'
  end

  def self.destination_class()
    return Asset
  end
end
