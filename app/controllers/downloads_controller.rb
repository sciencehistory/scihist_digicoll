class DownloadsController < ApplicationController
  # Will be sent to S3 as expires_in, seconds, max 1 week.
  URL_EXPIRES_IN = 2.days.to_i

  before_action :set_asset
  before_action :set_derivative, only: :derivative


  #GET /downloads/:asset_id
  def original
    filename = DownloadFilenameHelper.filename_with_suffix(
      DownloadFilenameHelper.filename_base_from_parent(@asset),
      asset: @asset
    )

    redirect_to @asset.file.url(
      expires_in: URL_EXPIRES_IN,
      response_content_type: @asset.content_type,
      response_content_disposition: ContentDisposition.format(
        disposition: content_disposition_mode,
        filename: filename
      ),
      status: 302
    )
  end

  #GET /downloads/:asset_id/:derivative_key
  def derivative
    filename = DownloadFilenameHelper.filename_with_suffix(
      [DownloadFilenameHelper.filename_base_from_parent(@asset), params[:derivative_key]].join("_"),
      content_type: @derivative.content_type
    )

    redirect_to @derivative.file.url(
      expires_in: URL_EXPIRES_IN,
      response_content_type: @derivative.content_type,
      response_content_disposition: ContentDisposition.format(
        disposition: content_disposition_mode,
        filename: filename
      ),
      status: 302
    )
  end

  private

  # sets @asset, but also aborts by raising RecordNotFound if permission denied, or asset is not yet promoted/stored.
  def set_asset
    @asset = Asset.find_by_friendlier_id!(params[:asset_id])

    authorize! :read, @asset

    unless @asset.stored?
      raise ActiveRecord::RecordNotFound.new("No downloads allowed for non-promoted Asset '#{@asset.id}' or its derivatives",
                                              "Kithe::Asset")
    end
  end

  # sets @derivative (for derivatives action), raises RecordNotFound if we can't find it.
  def set_derivative
    @derivative = @asset.derivative_for(params[:derivative_key])
    unless @derivative
      # We could use custom subclass of RecordNotFound with machine-readable details
      raise ActiveRecord::RecordNotFound.new("Couldn't find Kithe::Derivative for '#{@asset.id}' with key '#{params[:derivative_key]}'",
                                              "Kithe::Derivative")
    end
  end

  def content_disposition_mode
    params["disposition"] == "inline" ? "inline" : "attachment"
  end
end
