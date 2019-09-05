module DownloadOptions
  # Various resized JPG options for a single Asset of type "image/"
  #
  # It does NOT check that a derivative EXISTS before adding it to the options.
  class ImageDownloadOptions < ViewModel
    alias_method :asset, :model

    def initialize(asset)
      super(asset)
    end

    def options
      options = []

      # We don't use content_type in derivative option subheads,
      # cause it's in the main label. But do use it for original.

      # We generate derivative links without actually checking for derivative presence,
      # because it is much more efficient. We don't have derivative info though,
      # so can't include file size, and have to estimate calculate width and height.

      options << DownloadOption.with_formatted_subhead("Small JPG",
        url: download_derivative_path(asset, :download_small),
        analyticsAction: "download_jpg_small",
        width: width_for(:small),
        height: height_for(:small)
      )

      options << DownloadOption.with_formatted_subhead("Medium JPG",
        url: download_derivative_path(asset, :download_medium),
        analyticsAction: "download_jpg_medium",
        width: width_for(:medium),
        height: height_for(:medium)
      )

      options << DownloadOption.with_formatted_subhead("Large JPG",
        url: download_derivative_path(asset, :download_large),
        analyticsAction: "download_jpg_large",
        width: width_for(:large),
        height: height_for(:large)
      )

      options << DownloadOption.with_formatted_subhead("Full-sized JPG",
        url: download_derivative_path(asset, :download_full),
        analyticsAction: "download_jpg_full",
        width: asset.width,
        height: asset.height
      )

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

    private

    def width_for(download_size)
      Asset::IMAGE_DOWNLOAD_WIDTHS[download_size]
    end

    def height_for(download_size)
      # calc from aspect ratio
      ((asset.height.to_f / asset.width.to_f) * width_for(download_size)).round
    end
  end
end
