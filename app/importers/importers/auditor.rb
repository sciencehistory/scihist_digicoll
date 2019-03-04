require "json"
require "byebug"
module Importers
class Auditor

  attr_reader :path, :metadata, :item, :report_file

  def initialize(path, file, options = {})
    #raise ArgumentError unless target_item.is_a? self.class.exportee
    @path = path
    @file = file
    @metadata = {}
  end

  def check_item()
    # Parse the metadata from a file into @metadata.
    read_from_file()
    load_item()
    if @item.nil?
      report_line("Item not found in database.")
    end
    common_checks()
    special_checks()
  end

  # Common checks for Assets, Files and Collections.
  def common_checks()
    confirm(metadata['id'] == item.friendlier_id, "friendlier_id")
    unless metadata['date_uploaded'].nil?
      if item.created_at.nil?
        report_line("Missing create_date.")
      else
        confirm(item.created_at == DateTime.parse(metadata['date_uploaded']), "created_at")
      end
    end
  end

  def confirm(condition, report_string)
    report_line(report_string) unless condition
  end

  def special_checks()
    raise NotImplementedError
  end

  def report_line(str)
    @file.puts("#{@item.type} #{@item.friendlier_id}: #{str}")
  end

  def read_from_file()
    file = File.read(@path)
    @metadata = JSON.parse(file)
  end

  def load_item()
    klass = self.class.destination_class
    matches = klass.where(friendlier_id:@metadata['id'])
    @item = (matches == [] ? nil : matches.first)
  end

  def self.importee()
    raise NotImplementedError
  end

  def self.destination_class()
    raise NotImplementedError
  end

  def self.file_paths()
     files = Dir.entries(dir).select{|x| x.end_with? ".json"}
     files.map{|x| File.join(dir,x)}
  end

  def self.dir()
    Rails.root.join('tmp', 'import', dirname)
  end

  def self.dirname()
    "#{importee.downcase}s"
  end
end
end
