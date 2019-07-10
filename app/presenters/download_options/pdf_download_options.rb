module DownloadOptions
  # Download options for PDF original -- actually only original
  class PdfDownloadOptions < ViewModel
    alias_method :asset, :model

    def initialize(asset)
      super(asset)
    end

    def options
      options = []

      options << DownloadOption.new("Original file",
        url: download_path(asset),
        analyticsAction: "download_original",
        subhead: "#{ScihistDigicoll::Util.humanized_content_type(asset.content_type)} — #{asset.width} x #{asset.height}px — #{number_to_human_size asset.size}"
      )

      return options
    end

  end
end
