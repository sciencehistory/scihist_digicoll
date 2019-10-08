require "shrine"
require "shrine/storage/file_system"
require "down"
module Importers

class Importers::FileSetAuditor < Importers::Auditor

  # Checks specific to the imported class.
  def special_checks()
    confirm(@item.sha1 == @metadata['sha_1'], "sha_1")
    confirm(@item.title == @metadata["title_for_export"], 'title')
    confirm(@item.file.metadata['filename'] == @metadata['filename_for_export'], 'file data filename') unless @item.file.nil?
    unless @item.stored?
      report_line("Does not have a stored file.")
      if @metadata['sha_1'].nil?
        report_line("Expected sha1 is not in the exported file.")
      else
        report_line("Expected sha1 is: #{@metadata['sha_1']}.")
      end
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
