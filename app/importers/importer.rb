require "json"

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

  def remove_stale_item()
    klass = self.class.destination_class
    klass.where(friendlier_id:@metadata['id']).destroy_all
    #stale_item = self.class.destination_class.find_by_friendlier_id(@metadata['id'])
    #stale_item.delete
    # @metadata.select { |key, value| value!=[] && value != nil }
  end

  def post_clean()
    # @metadata.select { |key, value| value!=[] && value != nil }
  end

  def save_item()
    # reads metadata from file, creates an item based on it, returns it
    read_from_file()
    remove_stale_item()
    pre_clean()
    edit_metadata()
    post_clean()

    @new_item = self.class.destination_class().new()
    # new_item.friendlier_id = metadata['id']
    # new_item.title = metadata['title']

    populate()
    @new_item.save()

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
    @new_item.errors
  end


  #take a new item and add all metadata to it. Do not save.
  def populate()
    @new_item.friendlier_id = @metadata['id']
    @new_item.title = @metadata['title'].first
  end


  # subclass this to edit the hash that gets used by the populate function...
  def edit_metadata()
  end


  # the old thing importee class name, as a string, e.g. 'FileSet'
  def self.importee()
    raise NotImplementedError
  end

  # the new thing importee class, e.g. Asset
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