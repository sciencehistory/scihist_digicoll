module DownloadOptions
  # Various resized JPG options for a single Asset of type "image/"
  #
  # It actually checks that a derivative EXISTS before adding it to the options.
  #
  # Thus, we can actually use this for producing download options for PDFs too -- none
  # of the jpg download derivatives will exist, so they won't be included, and it'll just
  # add an 'original' link. Or for any other type that won't have standard image dl derivs,
  # and we only want an 'original' option.
  class ImageDownloadOptions < ViewModel
    alias_method :asset, :model

    def initialize(asset)
      super(asset)
    end

    def options
      options = []

      # We don't use content_type in derivative option subheads,
      # cause it's in the main label. But do use it for original.

      if dl_small = asset.derivative_for(:download_small)
        options << DownloadOption.with_formatted_subhead("Small JPG",
          url: download_derivative_path(asset, :download_small),
          analyticsAction: "download_jpg_small",
          width: dl_small.width,
          height: dl_small.height,
          size: dl_small.size
        )
      end

      if dl_medium = asset.derivative_for(:download_medium)
        options << DownloadOption.with_formatted_subhead("Medium JPG",
          url: download_derivative_path(asset, :download_medium),
          analyticsAction: "download_jpg_medium",
          width: dl_medium.width,
          height: dl_medium.height,
          size: dl_medium.size
        )
      end

      if dl_large = asset.derivative_for(:download_large)
        options << DownloadOption.with_formatted_subhead("Large JPG",
          url: download_derivative_path(asset, :download_large),
          analyticsAction: "download_jpg_large",
          width: dl_large.width,
          height: dl_large.height,
          size: dl_large.size
        )
      end

      if dl_full = asset.derivative_for(:download_full)
        options << DownloadOption.with_formatted_subhead("Full-sized JPG",
          url: download_derivative_path(asset, :download_full),
          analyticsAction: "download_jpg_full",
          width: dl_full.width,
          height: dl_full.height,
          size: dl_full.size
        )
      end

      if asset.stored?
        options << DownloadOption.with_formatted_subhead("Original file",
          url: download_path(asset),
          analyticsAction: "download_original",
          content_type: asset.content_type,
          width: asset.width,
          height: asset.height,
          size: asset.size
        )
      end

      return options
    end

  end
end
