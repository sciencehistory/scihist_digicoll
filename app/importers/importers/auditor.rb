require "json"
require "byebug"
module Importers
class Auditor

  attr_reader :metadata, :item, :report_file

  # metadata is the hash read from a json import file
  # file is a (temporary) log file to write audit problems to.
  def initialize(metadata, file, options = {})
    #raise ArgumentError unless target_item.is_a? self.class.exportee
    @file = file
    @metadata = metadata
  end

  def check_item()
    # Parse the metadata from a file into @metadata.
    load_item()
    if @item.nil?
      report_line("Item not found in database.")
      return
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
    confirm(item.published? == (metadata["access_control"] == "public"), "published")
  end

  def confirm(condition, report_string)
    report_line(report_string) unless condition
  end

  def special_checks()
    raise NotImplementedError
  end

  def report_line(str)
    prefix = if @item
      "#{@item.type} #{@item.friendlier_id}"
    else
      "#{self.class.name} #{metadata["id"]}"
    end

    @file.puts("#{prefix}: #{str}")
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
end
end
