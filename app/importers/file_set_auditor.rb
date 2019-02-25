require "shrine"
require "shrine/storage/file_system"
require "down"
require "byebug"

class FileSetAuditor < Auditor

  # Checks specific to the imported class.
  def special_checks()
    confirm(item.sha1 == @metadata['sha_1'], "sha_1")

    confirm(item.title == @metadata['title'].first, "title")

    # TODO:: label
    # confirm(item.filename == @metadata['label'])

  end

  def self.importee()
    return 'FileSet'
  end

  def self.destination_class()
    return Asset
  end
end
