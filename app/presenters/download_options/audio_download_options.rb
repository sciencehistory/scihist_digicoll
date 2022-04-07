module DownloadOptions
  # Download options for an asset of type "audio/", original and an mp3
  class AudioDownloadOptions
    include Rails.application.routes.url_helpers

    attr_reader :asset

    def initialize(asset)
      @asset = asset
    end

    def options
      options = []

      # We don't use content_type in derivative option subheads,
      # cause it's in the main label. But do use it for original.

      if asset.stored?
        options << DownloadOption.with_formatted_subhead("Original file",
          url: download_path(asset.file_category, asset),
          analyticsAction: "download_original",
          content_type: asset.content_type,
          size: asset.size
        )
      end

      return options
    end

  end
end
