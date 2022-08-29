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

      if m4a_deriv = asset.file_derivatives[:m4a]
        options << DownloadOption.with_formatted_subhead("Smaller file",
          url: download_derivative_path(asset, :m4a),
          analyticsAction: "download_m4a_derivative_of_flac_original",
          content_type: 'audio/mp4',
          size: m4a_deriv.size
        )
      end

      if asset.stored?
        options << DownloadOption.with_formatted_subhead("Original file",
          url: download_path(asset.file_category, asset),
          analyticsAction: "download_original",
          content_type: asset.content_type,
          size: asset.size
        )
      end

      options
    end

  end
end
