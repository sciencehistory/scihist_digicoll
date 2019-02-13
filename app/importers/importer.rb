require "json"
require 'byebug'

class Importer
  attr_reader :path, :metadata, :new_item


  def initialize(path, options = {})
    #raise ArgumentError unless target_item.is_a? self.class.exportee
    @path = path
    @metadata = {}
  end

  # takes file, returns metadata
  def read_from_file()
    file = File.read(@path)
    @metadata = JSON.parse(file)
  end

  def pre_clean()
  end

  def preexisting_item()
    # There can be at most one such preexisting item
    # if we trust the uniqueness of the key.
    klass = self.class.destination_class
    matches = klass.where(friendlier_id:@metadata['id'])
    matches == [] ? nil : matches.first
  end

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
    p_i.contained_by = []
    p_i.delete
  end

  def post_clean()
  end

  # Subclass this and return true for items that
  # don't need to be imported for whatever reason.
  # For now, we're skipping Assets if an Asset already
  # exists with the same friendlier_id and the
  # same sha_1 hash.
  def ok_to_skip_this_item()
    false
  end

  def save_item()
    # reads metadata from file, creates an item based on it, saves it
    read_from_file()
    return if ok_to_skip_this_item
    remove_stale_item()
    pre_clean()
    edit_metadata()
    post_clean()
    @new_item = self.class.destination_class().new()
    populate()
    @new_item.save!
    post_processing()
    set_create_date()
  end

  # This is run after each item is saved.
  def post_processing()
  end

  def set_create_date()
    return if metadata['date_uploaded'].nil?
    new_item.created_at = Date.parse(metadata['date_uploaded'])
    new_item.save!
  end


  def errors()
    return [] if @new_item.nil?
    @new_item.errors.full_messages
  end

  #How many seconds to wait after importing this item
  def how_long_to_sleep()
    0
  end

  #take a new item and add all metadata to it. Do not save.
  def populate()
    @new_item.friendlier_id = @metadata['id']
    @new_item.title = @metadata['title'].first
  end


  # subclass this to edit the hash that gets used by the populate function...
  def edit_metadata()
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

  def self.dirname()
    "#{importee.downcase}s"
  end

  # This gets called only after all items in this class are saved in the DB and thus have UUIDs.
  def self.class_post_processing()
  end

end
