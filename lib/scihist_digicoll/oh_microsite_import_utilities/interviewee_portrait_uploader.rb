# Utility methods for oral history microsite import.
# See:
# scihist:oh_microsite_import:import_interviewee_biographical_metadata
require "shrine"

module OhMicrositeImportUtilities
  class IntervieweePortraitUploader
    attr_accessor :work, :download_source, :title, :alt, :caption

    def initialize(args)
      @work     = args[:work]
      @filename = args[:filename]
      @url      = args[:url]
      @title    = args[:title]
      @alt      = args[:alt]
      @caption  = args[:caption]
    end

    # Try creating a portrait if none exists.
    def maybe_upload_file
      return unless portrait_asset.nil?
      portrait = new_portrait()
      if portrait.save
        @work.representative = portrait
        @work.save
      end
    end

    # If the portrait already exists, update its metadata
    def maybe_update_metadata
      return if portrait_asset.nil?
      portrait_asset.title = @title
      portrait_asset.admin_note = [
        "Title: \"#{@title}\"",
        "Filename: \"#{@filename}\"",
        "Downloaded from: \"#{@url}\"",
        "Alt text: \"#{@alt}\"",
        "Caption: \"#{@caption}\"",
      ]
    end

    def new_portrait
      portrait = Asset.new(
        title: @title,
        position: next_open_position,
        parent_id: @work.id,
        published: @work.published,
        role: 'portrait',
        )
        portrait.file_attacher.set_promotion_directives(promote: "inline")
        portrait.file_attacher.set_promotion_directives(create_derivatives: "inline")
        begin
          portrait.file = { "id" => @url, "storage" => "remote_url" }
        rescue Shrine::Error => shrine_error
          puts("Shrine error: #{shrine_error}")
        end
      portrait
    end

    def next_open_position
      work.members.map{|mem| mem.position.to_i}.max + 1
    end

    def portrait_asset
      work.members.find {|mem| mem.attributes['role'] == 'portrait'}
    end
  end
end