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
    # options:
    # keep_conflicting_items: default true, if false will delete conflicting items to make room for incoming items.
    def initialize(metadata, options = {})
      #raise ArgumentError unless target_item.is_a? self.class.exportee
      @metadata = metadata
      @errors ||= []
      @keep_conflicting_items = !!options[:keep_conflicting_items]
    end


    # Returns an ActiveRecord model instance, that is the primary target item to save in the import.
    # * Will find an existing object in the db if it exists,
    # * or a new AR model if it didn't already exist.
    #
    # Lazily loads with memoization, so checks the db on first time you call it, after that remembers
    # the object it came up with before, so you can call it as much as you want.
    #
    # Often used in #populate for setting metadata based on import json files:
    #     target_item.title = "whataever"
    #
    # Also sets ivar @preexisting_item_was_found for use with `#preexisting_item?` as a side-effect (bit hacky,
    # but we're refactoring here.)
    def target_item
      @conflicting_item = nil
      @target_item ||= begin
        item_with_same_friendlier_id = Kithe::Model.where(friendlier_id:metadata['id']).first
        if item_with_same_friendlier_id.is_a? self.class.destination_class                 
          model_object = item_with_same_friendlier_id
        else
          @conflicting_item = item_with_same_friendlier_id
          if @keep_conflicting_items
            add_error("Found a conflicting #{@conflicting_item.type}.")
            return
            # the calling method, @preexisting_item? will notice the conflict and skip importing this item.
          else
            add_error("Destroying #{@conflicting_item.type}  #{ @conflicting_item.friendlier_id }.")
            @conflicting_item.destroy
            # do not return; continue as usual now that the conflict is resolved.
          end
        end
        if (model_object)
          @preexisting_item_was_found = true
        else
          @preexisting_item_was_found = false
          # wasn't already existing in db, we need to create one
          model_object = self.class.destination_class.new
        end
        model_object
      end
    end

    # Is there a preexisting item with the same friendlier_id and the same type?
    def preexisting_item?
      # Calling target_item:
      #   * checks for any conflicting items
      #       * deletes them if it is allowed to,
      #       * sets ivar @conflicting_item otherwise.
      #   * creates or sets @target_item (without blanking it out -- that's done in the import method.)
      #   * sets boolean ivar @preexisting_item_was_found
      target_item
      # If a conflicting item with the same friendlier_id but a different type was found... return false.
      return false if @conflicting_item
      @preexisting_item_was_found
    end

    # This is the only method called on this class
    # by the rake task after instantiation.
    # It reads metadata from file, creates or finds
    # an item based on it, blanks out some of its metadata for freshening up from import if needed, 
    # then saves it to the database.
    def import
      self.class.without_auto_timestamps do
        if preexisting_item?
          blank_out_for_reimport(target_item)
        end
        if @conflicting_item
          add_error("Not importing this item:there is a conflicting #{@conflicting_item.type} with the same ID.").
          return
        end
        common_populate
        populate
        save_target_item
      end
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
      things_to_wipe = model.attributes.keys - ['file_data', 'id', 'type', 'updated_at', 'created_at', 'type', 'kithe_model_type']
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

      if metadata['date_uploaded'].blank?
        add_error("missing 'date_uploaded'")
        target_item.created_at = DateTime.now
      else
        target_item.created_at = DateTime.parse(metadata['date_uploaded'])
      end


      if metadata['date_modified'].blank?
        add_error("missing 'date_modified'")
        target_item.updated_at = DateTime.now
      else
        target_item.updated_at = DateTime.parse(metadata['date_modified'])
      end

      if metadata["access_control"].blank?
        add_error("missing 'access_control'")
      elsif metadata["access_control"] == "public"
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

    # turn off autotimestamps for our relevant classes, so we can
    # set updated_at ourself to match old system
    def self.without_auto_timestamps
      original = Kithe::Model.record_timestamps
      Kithe::Model.record_timestamps = false
      yield
    ensure
      Kithe::Model.record_timestamps = original
    end

    def same_friendlier_id_different_type
      Kithe::Model.where(friendlier_id:metadata['id']).where.not(type:self.class.destination_class.to_s).first
    end
  end
end
