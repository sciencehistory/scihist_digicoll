require "shrine"
require "shrine/storage/file_system"
require "down"
require "byebug"
module Importers

class Importers::FileSetAuditor < Importers::Auditor

  # Checks specific to the imported class.
  def special_checks()
    confirm(@item.sha1 == @metadata['sha_1'], "sha_1")
    confirm(@item.title == @metadata["title_for_export"], 'title')
    confirm(@item.file.metadata['filename'] == @metadata['filename_for_export'], 'file data filename') unless @item.file.nil?
  end

  def self.importee()
    return 'FileSet'
  end

  def self.destination_class()
    return Asset
  end
end
end
