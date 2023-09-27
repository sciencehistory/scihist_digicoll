module DownloadOptions
  # Various resized JPG options for a single Asset of type "image/"
  #
  # It actually checks that a derivative EXISTS before adding it to the options.
  #
  # Thus, we can actually use this for producing download options for PDFs too -- none
  # of the jpg download derivatives will exist, so they won't be included, and it'll just
  # add an 'original' link. Or for any other type that won't have standard image dl derivs,
  # and we only want an 'original' option.
  class ImageDownloadOptions
    include Rails.application.routes.url_helpers

    attr_reader :asset

    def initialize(asset, show_pdf_link: false)
      @asset = asset
      @show_pdf_link = show_pdf_link
    end

    def show_pdf_link?
      !!@show_pdf_link
    end

    def options
      options = []
      # Sometimes we want the PDF link in the individual-image download links,
      # as per https://github.com/sciencehistory/scihist_digicoll/issues/2278 .
      if show_pdf_link?
        options << DownloadOption.for_on_demand_derivative(
          label: "PDF", derivative_type: "pdf_file", work_friendlier_id: @asset&.parent&.friendlier_id
        )
      end

      # We don't use content_type in derivative option subheads,
      # cause it's in the main label. But do use it for original.


      # For historial reasons we have two download sizes MEDIUM and LARGE,
      # but we label the medium one as "small"
      if dl_medium = asset.file_derivatives[:download_medium]
        options << DownloadOption.with_formatted_subhead("Small JPG",
          work_friendlier_id: @asset.parent&.friendlier_id,
          url: download_derivative_path(asset, :download_medium),
          analyticsAction: "download_jpg_medium",
          width: dl_medium.width,
          height: dl_medium.height,
          size: dl_medium.size
        )
      end

      if dl_large = asset.file_derivatives[:download_large]
        options << DownloadOption.with_formatted_subhead("Large JPG",
          work_friendlier_id: @asset.parent&.friendlier_id,
          url: download_derivative_path(asset, :download_large),
          analyticsAction: "download_jpg_large",
          width: dl_large.width,
          height: dl_large.height,
          size: dl_large.size
        )
      end

      if dl_full = asset.file_derivatives[:download_full]
        options << DownloadOption.with_formatted_subhead("Full-sized JPG",
          url: download_derivative_path(asset, :download_full),
          work_friendlier_id: @asset.parent&.friendlier_id,
          analyticsAction: "download_jpg_full",
          width: dl_full.width,
          height: dl_full.height,
          size: dl_full.size
        )
      end

      if asset.stored?
        options << DownloadOption.with_formatted_subhead("Original file",
          url: download_path(asset.file_category, asset),
          work_friendlier_id: @asset.parent&.friendlier_id,
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
