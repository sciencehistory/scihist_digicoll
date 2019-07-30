require "shrine"
require "shrine/storage/file_system"
require "down"

module Importers
  class FileSetImporter < Importers::Importer

    # options:
    #   disable_bytestream_import: if set to true,
    #     we won't actually import any bytestreams at all, whether they were already
    #     there or not. Still import Asset models, but no `#file` in there. Can create
    #     inconsistent data in the import, missing files, but useful for testing runthroughs.
    #   create_derivatives: default false, if true will force inline derivative creation
    def initialize(metadata, options = {})
      super
      @disable_bytestream_import = !!options[:disable_bytestream_import]
      @create_derivatives = !!options[:create_derivatives]
    end


    # If we know the username and password for Fedora,
    # add them to the file URL. The admin user can download
    # originals from Fedora even if they're marked private.
    #
    # Should come from local_env.yml, or you can always set an ENV
    # IMPORT_FEDORA_AUTH="user:password"
    def corrected_file_url
      return nil if @metadata['file_url'].nil?
      return metadata["file_url"] unless ScihistDigicoll::Env.lookup(:import_fedora_auth).present?

      @metadata['file_url'].sub('http://', "http://#{ScihistDigicoll::Env.lookup(:import_fedora_auth)}@")
    end

    def blank_out_for_reimport(item)
      super

      if should_import_bytestream?
        # take care of removing the file we're about to import.
        # TODO: Maybe should let kithe/shrine take care of this, in a way that there's
        # never a missing file even temporarily. But have to confirm kithe/shrine will,
        # especially without using bg jobs.
        wipe_file_and_derivatives(item)
      end

      # Wipe other stale metadata, regardless.
      item.position= nil
      item.parent=nil
      item.title="_"
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
      return true if !preexisting_item?
      target_item.sha1 != metadata['sha_1']
    end

    # Assets actually have minimal metadata, so this method basically
    # fetches the file from Fedora and (possibly) generates the derivatives.
    def populate
      if should_import_bytestream?
       assign_import_bytestream
      end

      # This gets executed even if the file's checksum is correct:
      unless target_item.file.nil? || target_item.file.metadata.nil?
         target_item.file.metadata['filename'] = metadata['filename_for_export']
      end
      target_item.title = metadata["title_for_export"]
    end

    def assign_import_bytestream
      # This tells target_item's shrine uploader to do promotion inline instead of
      # kicking off a background job.
      target_item.file_attacher.set_promotion_directives(promote: "inline")
      # Now the promotion is happening inline (not in a bg job), but the promotion will ordinarily
      # kick off yet another job for derivatives creation.
      # We can either tell it NOT to do derivatives creation at all, or
      # we can tell it to do it inline (no bg job)
      if @create_derivatives
        target_item.file_attacher.set_promotion_directives(create_derivatives: "inline")
      else
        target_item.file_attacher.set_promotion_directives(create_derivatives: false)
      end

      # This should never happen with production data,
      # but it should also not stop the entire import.
      begin
        target_item.file = { "id" => corrected_file_url, "storage" => "remote_url" }
      rescue Shrine::Error => shrine_error
        add_error("Shrine error: #{shrine_error}")
      end

    end

    def self.importee()
      return 'FileSet'
    end

    def self.destination_class()
      return Asset
    end
  end
end
