require "shrine"
require "shrine/storage/file_system"
require "down"
require "byebug"
module Import

class Import::FileSetAuditor < Import::Auditor

  # Checks specific to the imported class.
  def special_checks()
    confirm(@item.sha1 == @metadata['sha_1'], "sha_1")
    confirm(@item.title == @metadata['title'].first, "title")
    confirm(@item.file_data['filename'] == @metadata['label'], 'file data filename') unless @item.file_data.nil?
  end
  
  def self.importee()
    return 'FileSet'
  end

  def self.destination_class()
    return Asset
  end
end
end
