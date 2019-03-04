require "json"
require "byebug"

# This class knows about all the common functionality
# needed to ingest an individual Asset or Work or Collection
# from the old chf-sufia repository.
# This class is called from lib/tasks/import.rake ; more info about
# how to run the task may be found at that file.

module Importers
class Importer

  # path is where to find the json import file for this item
  # metadata will contain the item's metadata once that json file is parsed
  # new_item will contain the actual item that we want to save to the database.
  attr_accessor :path, :metadata, :new_item, :progress_bar

  @@progress_bar = nil

  # Creates the importer and assigns the path to the json file
  # it's going to try to import.
  # At the moment we don't use options.
  def initialize(path, progress_bar, options = {})
    #raise ArgumentError unless target_item.is_a? self.class.exportee
    @path = path
    @metadata = {}
    @@progress_bar ||= progress_bar
  end

  # This is the only method called on this class
  # by the rake task after instantiation.
  # It reads metadata from file, creates
  # an item based on it, then saves it to the database.
  def save_item()
    # Parse the metadata from a file into @metadata.
    read_from_file()

    # Make any adjustments to @metadata before it's applied to
    # to the new item.
    edit_metadata()

    if preexisting_item.nil?
      # Create the Asset, Work or Collection that we want to ingest.
      @new_item = self.class.destination_class().new()
    else
      # If a stale item already exists in the system from a prior ingest,
      # wipe the stale item so it can be updated
      @new_item = wipe_stale_item()
    end


    # Apply the metadata from @metadata to the @new_item.
    populate()

    begin
      @new_item.save!
    rescue
      if @new_item.errors.first == [:date_of_work, "is invalid"]
        report_via_progress_bar("ERROR: bad date: #{metadata['dates']}")
        @new_item.date_of_work = []
        @new_item.save!
      elsif (!@new_item.errors.first.nil?) && @new_item.errors.first.first == :related_url
        report_via_progress_bar("ERROR: bad related_url: #{metadata['related_url']}")
        new_item.related_url = []
        @new_item.save!
      end
    end

    # Any tasks that need to be applied *after* save.
    # Typically these tasks involve associating the newly-created @new_item
    # with other items in the database.
    post_processing()

    @@progress_bar.increment
    unless errors == []
      report_via_progress_bar(errors)
    end


  end

  # Parse the json file and add its contents to @metadata.
  def read_from_file()
    file = File.read(@path)
    @metadata = JSON.parse(file)
  end

  # Any initial adjustments to the metadata.
  # Not currently implemented in any subclasses;
  # we may not really need this method.
  def pre_clean()
  end

  # subclass this to edit the hash that gets used by the populate function...
  def edit_metadata()
  end

  def preexisting_item()
    # There can be at most one such preexisting item
    # if we trust the uniqueness of the key.
    klass = self.class.destination_class

    # TODO replace this by find_by_friendlier_id
    matches = klass.where(friendlier_id:@metadata['id'])
    matches == [] ? nil : matches.first
  end


  def wipe_stale_item()
    p_i = preexisting_item
    raise RuntimeError, "Can't wipe a nil item." if p_i.nil?

    # To avoid duplicates...
    p_i.members.each do |child|
      child.parent = nil
      child.save!
    end

    (Kithe::Model.where representative_id: p_i.id).each do |r|
      r.representative_id = nil
      r.save!
    end

    (Kithe::Model.where leaf_representative_id: p_i.id).each do |r|
      r.leaf_representative_id = nil
      r.save!
    end

    p_i.contains = [] if p_i.is_a? Collection
    p_i.contained_by = []

    # and ordinary attributes too:

    p_i.json_attributes = {}
    things_to_wipe = p_i.attributes.keys - ['file_data', 'id', 'type', 'updated_at', 'created_at']
    things_to_wipe.each { | atttr | p_i.send("#{atttr}=", nil) }
    return p_i
  end

  # This is run after each item is saved.
  # Useful for associating the item with other already-ingested items,
  # or storing info about the item so it can be associated with
  # items soon to be ingested.
  # Not to be confused with class_post_processing, which
  # runs only after all items of this type have already been ingested.
  def post_processing()
  end

  # A shortcut method for logging any errors.
  def errors()
    return [] if @new_item.nil?
    @new_item.errors.full_messages
  end

  # Take the new item and add all metadata to it.
  # This do not save the item.
  # The three subclasses call this via super but also
  # add a fair amount of their own metadata processing.
  def populate()
    @new_item.friendlier_id = @metadata['id']
    @new_item.title = @metadata['title'].first
    unless metadata['date_uploaded'].nil?
      @new_item.created_at = DateTime.parse(metadata['date_uploaded'])
    end
  end

  def report_via_progress_bar(msg)
    str = "#{self.class.importee} #{metadata['id']}: #{msg}"
    @@progress_bar.log(str)
  end

  # the old importee class name, as a string, e.g. 'FileSet'
  def self.importee()
    raise NotImplementedError
  end

  # the new importee class, e.g. Asset
  def self.destination_class()
    raise NotImplementedError
  end

  # An array of paths to all the files that this class can import
  def self.file_paths()
     files = Dir.entries(dir).select{|x| x.end_with? ".json"}
     files.map{|x| File.join(dir,x)}
  end

  def self.dir()
    Rails.root.join('tmp', 'import', dirname)
  end

  #The names of the directory where this sort of item's json files can be found.
  def self.dirname()
    "#{importee.downcase}s"
  end

  # This class method gets called only after all
  # items of a particular type are saved in the DB and thus have UUIDs.
  # Not to be confused with processing, which runs once for each item,
  # after the item has been saved.
  def self.class_post_processing()
  end

end
end
