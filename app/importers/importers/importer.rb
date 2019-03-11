require "json"

# This class knows about all the common functionality
# needed to ingest an individual Asset or Work or Collection
# from the old chf-sufia repository.
# This class is called from lib/tasks/import.rake ; more info about
# how to run the task may be found at that file.
#
# The general API for any importer is:
#     SomeImporter.new(metadata_hash).import
#
# Sub-classes will generally implement #populate to transfer data from
# #metadata to #target_item
module Importers
  class Importer

    # metadata will contain the item's metadata once that json file is parsed
    attr_accessor :metadata

    # Creates the importer and assigns the path to the json file
    # it's going to try to import.
    #
    # Argument metadata is a hash read from an individual import.json file, contents
    # differ depending on file type.
    def initialize(metadata, options = {})
      #raise ArgumentError unless target_item.is_a? self.class.exportee
      @metadata = metadata
      @errors ||= []
    end


    # Returns an ActiveRecord model instance, that is the primary target item to save in the import.
    # * Will find an existing object in the db, and blank out some of it's metadata for freshening up from import
    # * Or a new AR model if it didn't already exist.
    #
    # Lazily loads with memoization, so checks the db on first time you call it, after that remembers
    # the object it came up with before, so you can call it as much as you want.
    #
    # Often used in #populate for setting metadata based on import json files:
    #     target_item.title = "whataever"
    #
    # Also sets ivar @preexisting_item for use with `#preexisting_item?` as a side-effect (bit hacky,
    # but we're refactoring here.)
    def target_item
      return @target_item unless @target_item.nil?
      item_from_db = self.class.destination_class.where(friendlier_id:@metadata['id']).first
      if (item_from_db)
        @preexisting_item = true
        @target_item = item_from_db
        # let's wipe some of it out
        blank_out_for_reimport(@target_item)
      else
        @preexisting_item = false
        # wasn't already existing in db, we need to create one
        @target_item = self.class.destination_class.new
      end
      @target_item
    end # method

    # Won't work unless target_item was called first. Known problem, otherwise
    # we get an infinite loop in the FileSetImporter#blank_out_for_reimport method. :(
    def preexisting_item?
      @preexisting_item
    end

    # This is the only method called on this class
    # by the rake task after instantiation.
    # It reads metadata from file, creates
    # an item based on it, then saves it to the database.
    def import
      common_populate
      populate
      save_target_item
    end

    # After running, check #errors for any errors you may want to report
    # to the user.
    def save_target_item()
      begin
        target_item.save!
      rescue StandardError => e
        add_error("ERROR: Could not save record: #{e}")
      end
    end

    # when we have an object already in the db that we are targetting for an import,
    # we may want to blank out some of it's data before applying the import data.
    #
    # Does _not_ call "save" on model passed in, but may (for now) fetch and save other objects.
    def blank_out_for_reimport(model)
      raise RuntimeError, "Can't wipe a nil item." if model.nil?

      # Not sure we need to do this
      # To avoid duplicates...
      model.members.each do |child|
        child.parent = nil
        child.save!
      end

      # Not sure we need to do this
      (Kithe::Model.where representative_id: model.id).each do |r|
        r.representative_id = nil
        r.save!
      end

      # Not sure we need to do this
      (Kithe::Model.where leaf_representative_id: model.id).each do |r|
        r.leaf_representative_id = nil
        r.save!
      end

      # Not sure we need to do this
      model.contains = [] if model.is_a? Collection
      model.contained_by = []

      # and ordinary attributes too:

      model.json_attributes = {}
      # why not wipe updated_at and created_at too?
      things_to_wipe = model.attributes.keys - ['file_data', 'id', 'type', 'updated_at', 'created_at']
      things_to_wipe.each { | atttr | model.send("#{atttr}=", nil) }
      return model
    end

    # an error that will be shown to operator, often that means a record could
    # not be imported properly
    def add_error(str)
      @errors << str
    end

    # What errors have been accumulated? Includes any validation errors
    # on the record to be saved, and any errors added with #add_error
    def errors()
      (@errors + (target_item&.errors&.full_messages || [])).collect do |str|
        "#{self.class.importee} #{metadata['id']}: #{str}"
      end
    end


    # Take the new item and add all metadata to it.
    # This do not save the item.
    def common_populate()
      target_item.friendlier_id = @metadata['id']
      target_item.title = @metadata['title'].first
      unless metadata['date_uploaded'].nil?
        target_item.created_at = DateTime.parse(metadata['date_uploaded'])
      end

      if metadata["access_control"] == "public"
        target_item.published = true
      end
    end

    # no-op in base class, override in sub-class to do something
    def populate
    end

    # the old importee class name, as a string, e.g. 'FileSet'
    def self.importee()
      raise NotImplementedError
    end

    # the new importee class, e.g. Asset
    def self.destination_class()
      raise NotImplementedError
    end
  end
end
