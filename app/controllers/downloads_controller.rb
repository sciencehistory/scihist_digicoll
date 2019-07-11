# A controller for delivering our originals and assets to browser, via a redirect to an
# S3 url.
#
# send to `/downloads/:asset_friendlier_id` (`downloads_path(asset)`)  or
# `/downloads/:asset_friendlier_id/:derivative_key` (`downloads_derivative_path(asset, derivative_key)`)
#
# And a REDIRECT will be returned to an S3 asset, via a signed S3 url.
#
# The signed S3 urls generated will request a content-disposition header from S3, that
# will set a download filename based on current parent work and/or Asset metadata. For
# instance, based on Work title. This means it may not match the actual key/URL on S3,
# and can change when Work/Asset metadata changes without needing to change actual key/URL
# on S3.  See DownloadFilenameHelper for actual filename-generation logic, used here.
#
# However, since we are delivering a signed URL to do this (as well as give access to S3
# assets that may not be public -- after verifying auth), it also means the particular
# URL redirected to is unique to request, will expire, and is not generally cachable
# (either by shared HTTP caches or even specific browser-caches -- since you will never
# get the same URL twice).
#
# So this is an unfortuante tradeoff, and due to the redirect to an uncacheable URL, we
# do NOT use this controller for actual image and media source (eg`src` attribute on an `img`)
# for displaying in the browser -- for those we currently deliver the direct S3 URL to a
# _public_ S3 asset.
#
# So this controller is usually used for acutal downloads, although sending
# ?disposition=inline will result in an 'inline' disposition header, which we use for instance
# for asking the browser to display a PDF directly (if the browser can), which we may use
# for 'view' function on a PDF.  Even when being delivered with disposition inline, the
# content-disposition header still has a filename set, so if the user chooses 'save as'
# from their browser, they will still get our specified filename instead of just a filename
# based on S3 URL. Which is neat.
#
class DownloadsController < ApplicationController
  # Will be sent to S3 as expires_in, seconds, max 1 week.
  URL_EXPIRES_IN = 2.days.to_i

  before_action :set_asset
  before_action :set_derivative, only: :derivative


  #GET /downloads/:asset_id
  def original
    # Tell shrine url method `public:false` to make sure we get a signed URL
    # that lets us set content-disposition and content-type, even if
    # it's public in S3.
    redirect_to @asset.file.url(
      public: false,
      expires_in: URL_EXPIRES_IN,
      response_content_type: @asset.content_type,
      response_content_disposition: ContentDisposition.format(
        disposition: content_disposition_mode,
        filename: DownloadFilenameHelper.filename_for_asset(@asset)
      )
    ), status: 302
  end

  #GET /downloads/:asset_id/:derivative_key
  def derivative
    # Tell shrine url method `public:false` to make sure we get a signed URL
    # that lets us set content-disposition and content-type, even if
    # it's public in S3.
    redirect_to @derivative.file.url(
      public: false,
      expires_in: URL_EXPIRES_IN,
      response_content_type: @derivative.content_type,
      response_content_disposition: ContentDisposition.format(
        disposition: content_disposition_mode,
        filename: DownloadFilenameHelper.filename_for_asset(@asset, derivative: @derivative)
      )
    ), status: 302
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
