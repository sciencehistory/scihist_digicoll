require "shrine"
require "shrine/storage/file_system"
require "down"
require "byebug"

class FileSetAuditor < Auditor

  # Checks specific to the imported class.
  def special_checks()
  end

  def self.importee()
    return 'FileSet'
  end

  def self.destination_class()
    return Asset
  end
end
