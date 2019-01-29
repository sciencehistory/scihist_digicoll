require "shrine"
require "shrine/storage/file_system"
require "down"

# class ImportUploader < Kithe::AssetUploader

# end

class FileSetImporter < Importer

  def populate()
    # @new_item is an unsaved Asset

    # this _should_ tell @new_item's shrine uploader to do promotion inline instead of
    # kicking off a background job. somewhat experimental, don't be shocked if it doesn't
    # work but DO tell me if you think it's not working.
    @new_item.file_attacher.set_promotion_directives(promote: "inline")

    # Now the promotion is happening inline, but the promotion will ordinarily
    # kick off yet another job for derivatives creation.For now, let's tell it
    # NOT to do derivatives creation at all.

    #@new_item.file_attacher.set_promotion_directives(derivatives: false)
    @new_item.file_attacher.set_promotion_directives(derivatives: "inline")

    # or could be `derivatives: "inline"`

    # not doing this....
    #@new_item.file = an_io_object # Down.open(metadata['file_urls'].first)


    # alternately, this second way defers downloading of the remote url to the background job,
    # and should skip an extra copy in "cache".

    # `storage => "remote_url"` with that exact
    # literal is what tells the uploader it needs to retrieve a URL that is stored in "id" key.
    # id is actually the URL.
    @new_item.file = { "id" => metadata['file_urls'].first, "storage" => "remote_url"}

    super
  end

  def self.importee()
    return 'FileSet'
  end

  def self.destination_class()
    return Asset
  end
end
