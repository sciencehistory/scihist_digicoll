module DownloadOptions
  # Download options for an asset of type "audio/", original and an mp3
  class AudioDownloadOptions < ViewModel
    alias_method :asset, :model

    def initialize(asset)
      super(asset)
    end

    def options
      options = []

      # We don't use content_type in derivative option subheads,
      # cause it's in the main label. But do use it for original.

      if asset.stored?
        options << DownloadOption.with_formatted_subhead("Original file",
          url: download_path(asset),
          analyticsAction: "download_original",
          content_type: asset.content_type,
          size: asset.size
        )
      end

      return options
    end

  end
end
