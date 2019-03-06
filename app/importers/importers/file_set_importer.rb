require "shrine"
require "shrine/storage/file_system"
require "down"
require "byebug"

module Importers
class Importers::FileSetImporter < Importers::Importer

  # Load Fedora credentials (only once) into a
  # class variable, if we have them.
  if ENV['FEDORA_USERNAME'].nil? || ENV['FEDORA_PASSWORD'].nil?
    @@fedora_credentials = {}
  else
    @@fedora_credentials ||= {username: ENV['FEDORA_USERNAME'], password: ENV['FEDORA_PASSWORD']}
  end

  # options:
  #   disable_bytestream_import: if set to true,
  #     we won't actually import any bytestreams at all, whether they were already
  #     there or not. Still import Asset models, but no `#file` in there. Can create
  #     inconsistent data in the import, missing files, but useful for testing runthroughs.
  def initialize(path, progress_bar, options = {})
    super
    @disable_bytestream_import = !!options[:disable_bytestream_import]
  end



  # If we know the username and password for Fedora,
  # add them to the file URL. The admin user can download
  # originals from Fedora even if they're marked private.
  def edit_metadata()
    if @@fedora_credentials != {}
      basic_download_url = @metadata['file_url']
      return if basic_download_url.nil?
      credentials = "http://#{@@fedora_credentials[:username]}:#{@@fedora_credentials[:password]}@"
      @metadata['file_url'] = basic_download_url.sub('http://', credentials)
    end
  end

  def wipe_stale_item()
    p_i = preexisting_item
    raise RuntimeError, "Can't wipe a nil item." if p_i.nil?

    if should_import_bytestream?
      # take care of removing the file we're about to import.
      # TODO: Maybe should let kithe/shrine take care of this, in a way that there's
      # never a missing file even temporarily. But have to confirm kithe/shrine will,
      # especially without using bg jobs.
      wipe_file_and_derivatives(p_i)
    end

    # Wipe other stale metadata, regardless.
    p_i.position= nil
    p_i.parent=nil
    p_i.title="_"

    #important: return p_i
    return p_i
  end

  # The sha-1 hash on this asset says
  # remove file info and derivatives:
  def wipe_file_and_derivatives(asset_model)
    raise RuntimeError, "Can't wipe a nil item." if asset_model.nil?
    asset_model.file.delete unless asset_model.file.nil?
    asset_model.derivatives.destroy_all
    asset_model.file_data = {}
  end

  # If we already have an item, and it's file has a sha1 matching fedora's
  # sha1, we don't need to import the bytestream again, since it's already
  # there, which saves us lots of time on re-runs.
  def should_import_bytestream?
    return false if @disable_bytestream_import
    return true if preexisting_item.nil?
    preexisting_item.sha1 != metadata['sha_1']
  end

  # Assets actually have minimal metadata, so this method basically
  # fetches the file from Fedora and (possibly) generates the derivatives.
  def populate()
    super
    if should_import_bytestream?
      # This tells @new_item's shrine uploader to do promotion inline instead of
      # kicking off a background job.
      @new_item.file_attacher.set_promotion_directives(promote: "inline")
      # Now the promotion is happening inline (not in a bg job), but the promotion will ordinarily
      # kick off yet another job for derivatives creation.
      # We can either tell it NOT to do derivatives creation at all.
      # @new_item.file_attacher.set_promotion_directives(create_derivatives: false)
      # or we can tell it to create derivatives inline:
      @new_item.file_attacher.set_promotion_directives(create_derivatives: "inline")
      # where to get the file from:

      # file properties
      properties = { "id" => metadata['file_url'], "storage" => "remote_url" }
      @new_item.file = properties
      # end file properties
    end

    # This gets executed even if the file's checksum is correct:
    unless @new_item.file.nil? || @new_item.file.metadata.nil?
       @new_item.file.metadata['filename'] = metadata['filename_for_export']
    end
    @new_item.title = metadata["title_for_export"]
  end

  def self.importee()
    return 'FileSet'
  end

  def self.destination_class()
    return Asset
  end
end
end
