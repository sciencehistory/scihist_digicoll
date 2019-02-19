require "json"
require "byebug"

# This class knows about all the common functionality
# needed to ingest an individual Asset or Work or Collection
# from the old chf-sufia repository.
# This class is called from lib/tasks/import.rake ; more info about
# how to run the task may be found at that file.
class Importer

  # path is where to find the json import file for this item
  # metadata will contain the item's metadata once that json file is parsed
  # new_item will contain the actual item that we want to save to the database.
  attr_reader :path, :metadata, :new_item, :progress_bar

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
    # Figure out if there's already an item in the DB
    # that's fine for our purposes and doesn't need to be
    # reingested. If so, it's fine to move on to
    # the next item on our list.
    if ok_to_skip_this_item
      @@progress_bar.increment
      return
    end
    # If a stale item already exists in the system from a prior ingest,
    # remove the stale item so it can be replaced.
    remove_stale_item()
    # Make any adjustments to @metadata before it's applied to
    # to the new item.
    edit_metadata()
    # Create the Asset, Work or Collection that we want to ingest.
    @new_item = self.class.destination_class().new()
    # Apply the metadata from @metadata to the @new_item.
    populate()
    begin
      @new_item.save!
    rescue
      if @new_item.errors.first == [:date_of_work, "is invalid"]
        report_via_progress_bar("ERROR: bad date")
        @new_item.date_of_work = []
        @new_item.save!
      elsif
        new_item.errors.first.first == :related_url
        report_via_progress_bar("ERROR: bad related_url")
        new_item.related_url = []
        @new_item.save!
      end
    end
    # Any tasks that need to be applied *after* save.
    # Typically these tasks involve associating the newly-created @new_item
    # with other items in the database.
    post_processing()
    # Set the create date to the *original* create date from chf-sufia.
    # We do not store the ingest date.
    set_create_date()
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

  # Subclass this and return true for items that
  # don't need to be imported for whatever reason.
  # For now, we're skipping Assets if:
  # a) an Asset alread exists with the same
  # friendlier_id, and
  # b) that asset contains a file with the same sha_1 hash.
  def ok_to_skip_this_item()
    false
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
    matches = klass.where(friendlier_id:@metadata['id'])
    matches == [] ? nil : matches.first
  end

  # Context: We plan on re-ingesting improved updated versions of Work and
  # Collection metadata as we refine the import process. To reingest an item,
  # you need to first delete the item already in place with the same #friendlier_id.

  # However, by default, deleting a Work also deletes its child works
  # and assets, and deleting a Collection also deletes all the contents of the collection.

  # Instead, we:
  # * Figure out if another preexisting_item was already ingested
  # with the same friendlier_id as @new_item.
  # * For all children of preexisting_item, be they Assets or Works, remove
  # references to preexisting_item.
  # * For any items for which preexisting_item might be listed as the representative,
  # set the representative_id to null. (It will be re-added later).
  # * Same process for leaf_representative.
  # * preexisting_item is removed from any Collections it may be part of. Again,
  # the association will be re-established later.)
  # * Delete preexisting_item.

  # This method is guaranteed to:
  # a) not delete any items other than preexisting_item.
  # b) not to run afoul of any postgres foreign-key constraints.
  def remove_stale_item()
    raise RuntimeError, "Assets should not be removed by this method." if preexisting_item.is_a? Asset
    p_i = preexisting_item
    return if p_i.nil?
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
    p_i.delete
  end

  # This is run after each item is saved.
  # Useful for associating the item with other already-ingested items,
  # or storing info about the item so it can be associated with
  # items soon to be ingested.
  # Not to be confused with class_post_processing, which
  # runs only after all items of this type have already been ingested.
  def post_processing()
  end

  # Set the create date on the item so it's the same as its corresponding item in
  # chf-sufia.
  def set_create_date()
    return if metadata['date_uploaded'].nil?
    new_item.created_at = Date.parse(metadata['date_uploaded'])
    new_item.save!
  end

  # A shortcut method for logging any errors.
  def errors()
    return [] if @new_item.nil?
    @new_item.errors.full_messages
  end

  #How many seconds to wait after importing this item
  def how_long_to_sleep()
    0
  end

  # Take the new item and add all metadata to it.
  # This do not save the item.
  # The three subclasses call this via super but also
  # add a fair amount of their own metadata processing.
  def populate()
    @new_item.friendlier_id = @metadata['id']
    @new_item.title = @metadata['title'].first
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
