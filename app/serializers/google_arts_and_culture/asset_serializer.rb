module GoogleArtsAndCulture
  class GoogleArtsAndCulture::AssetSerializer < GoogleArtsAndCulture::KitheModelSerializer
    def initialize(model, callback: nil, attribute_keys:, column_counts:)
      @asset = model
      super
    end

    def metadata
      vals = {
        file_name:      filename,
        filetype:       filetype,
        friendlier_id:  @asset.parent.friendlier_id, # friendlier_id is just used for works
        subitem_id:     @asset.friendlier_id,
        order_id:       @asset.position || no_value,
        title:          @asset.title,
      }

      @attribute_keys.map do |k|
        count = @column_counts.dig(k.to_s)
        if count.nil?
          vals.fetch(k, not_applicable)
        else
          Array.new(count, not_applicable)
        end
      end.flatten
    end

    def file
      return []
    end

    def file
      if @asset.content_type == "image/jpeg"
        @asset.file
      else
        @asset.file_derivatives(:download_full)
      end
    end

    def filename
      return no_value if @asset&.file&.url.nil?
      "#{DownloadFilenameHelper.filename_base_from_parent(@asset)}.jpg"
    end

    def filetype
      if @asset.content_type&.start_with?("video/")
        'Video' # currently unavailable
      elsif @asset.content_type&.start_with?("image/")
        'Image'
      else
        not_applicable
      end
    end

  end
end
