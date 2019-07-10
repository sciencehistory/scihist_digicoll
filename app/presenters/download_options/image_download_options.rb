module DownloadOptions
  # Various resized JPG options for a single Asset of type "image/"
  class ImageDownloadOptions < ViewModel
    alias_method :asset, :model

    def initialize(asset)
      super(asset)
    end

    def options
      options = []


      if dl_small = asset.derivative_for(:download_small)
        options << DownloadOption.new("Small JPG",
          url: download_derivative_path(asset, :download_small),
          analyticsAction: "download_jpg_small",
          subhead: "#{dl_small.width} x #{dl_small.height}px — #{number_to_human_size dl_small.size}"
        )
      end

      if dl_medium = asset.derivative_for(:download_medium)
        options << DownloadOption.new("Medium JPG",
          url: download_derivative_path(asset, :download_medium),
          analyticsAction: "download_jpg_medium",
          subhead: "#{dl_medium.width} x #{dl_medium.height}px — #{number_to_human_size dl_medium.size}"
        )
      end

      if dl_large = asset.derivative_for(:download_large)
        options << DownloadOption.new("Large JPG",
          url: download_derivative_path(asset, :download_large),
          analyticsAction: "download_jpg_medium",
          subhead: "#{dl_large.width} x #{dl_large.height}px — #{number_to_human_size dl_large.size}"
        )
      end

      if dl_large = asset.derivative_for(:full_jpg)
        options << DownloadOption.new("Full-sized JPG",
          url: download_derivative_path(asset, :full_jpg),
          analyticsAction: "download_jpg_full",
          subhead: "#{dl_large.width} x #{dl_large.height}px — #{number_to_human_size dl_large.size}"
        )
      end

      if asset.stored?
        options << DownloadOption.new("Original file",
          url: download_path(asset),
          analyticsAction: "download_original",
          subhead: "#{ScihistDigicoll::Util.humanized_content_type(asset.content_type)} — #{asset.width} x #{asset.height}px — #{number_to_human_size asset.size}"
        )
      end

      return options
    end

  end
end
