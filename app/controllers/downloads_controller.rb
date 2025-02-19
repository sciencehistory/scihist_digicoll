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
  URL_EXPIRES_IN = 15.minutes.to_i # reduced to try to slow down bots. was 2.days.to_i

  before_action :set_asset
  before_action :set_derivative, only: :derivative

  before_action :turnstile_protect, only: :original, if: -> { ScihistDigicoll::Env.lookup(:cf_turnstile_downloads_enabled) }

  #GET /downloads/original/:asset_id
  def original
    # for IMAGES only, when we have downloads disable, simply refuse to redirect IF the user
    # is not logged in. PHEW lots of exceptions, trying to avoid breaking LOTS of our app.
    if ScihistDigicoll::Env.lookup(:disable_downloads) && !current_user && @asset.content_type.start_with?("image/")
      render status: 503, plain: "Sorry, this download is currently unavailable"

      return
    end

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
    ), status: 302, allow_other_host: true
  end

  #GET /downloads/:asset_id/:derivative_key
  def derivative
    # Tell shrine url method `public:false` to make sure we get a signed URL
    # that lets us set content-disposition and content-type, even if
    # it's public in S3.
    redirect_to @derivative.url(
      public: false,
      expires_in: URL_EXPIRES_IN,
      response_content_type: @derivative.content_type,
      response_content_disposition: ContentDisposition.format(
        disposition: content_disposition_mode,
        filename: DownloadFilenameHelper.filename_for_asset(@asset, derivative_key: params[:derivative_key].to_sym)
      )
    ), status: 302, allow_other_host: true
  end

  private

  # sets @asset, but also aborts by raising RecordNotFound if permission denied, or asset is not yet promoted/stored.
  def set_asset
    @asset = Asset.find_by_friendlier_id!(params[:asset_id])

    if cannot?(:read, @asset) && !is_requestable_oral_history_asset?(@asset)
      raise AccessGranted::AccessDenied.new(:read, @asset, 'Access Denied')
    end

    unless @asset.stored?
      raise ActiveRecord::RecordNotFound.new("No downloads allowed for non-promoted Asset '#{@asset.id}' or its derivatives",
                                              "Kithe::Asset")
    end
  end

  def is_requestable_oral_history_asset?(asset)
    return false unless asset.oh_available_by_request?

    oh_requester = OralHistorySessionsController.fetch_oral_history_current_requester(request: request)
    return false unless oh_requester

    oh_requester.has_approved_request_for_asset?(asset)
  end

  # sets @derivative (for derivatives action), raises RecordNotFound if we can't find it.
  def set_derivative
    @derivative = @asset.file_derivatives(params[:derivative_key].to_sym)
    unless @derivative
      # We could use custom subclass of RecordNotFound with machine-readable details
      raise ActiveRecord::RecordNotFound.new("Couldn't find Kithe::Derivative for '#{@asset.id}' with key '#{params[:derivative_key]}'",
                                              "Kithe::Derivative")
    end
  end

  def content_disposition_mode
    params["disposition"] == "inline" ? "inline" : "attachment"
  end

  # This maybe should be DRY'd with our page-redirect turnstile protection, currently
  # in local BotDetectController, being extracted to BotChallengePage gem. Or maybe it's
  # okay like so!
  def turnstile_protect
    # don't protect PDFs, we want google to crawl them
    return if @asset.content_type == "application/pdf"

    if params["cf_turnstile_response"].blank?
      raise HTTP::Error.new("No cf_turnstile_response param")
    end

    body = {
      secret: BotDetectController.cf_turnstile_secret_key,
      response: params["cf_turnstile_response"],
      remoteip: request.remote_ip
    }

    http = HTTP.timeout(BotDetectController.cf_timeout)
    response = http.post(BotDetectController.cf_turnstile_validation_url,
      json: body)

    result = response.parse
    # {"success"=>true, "error-codes"=>[], "challenge_ts"=>"2025-01-06T17:44:28.544Z", "hostname"=>"example.com", "metadata"=>{"result_with_testing_key"=>true}}
    # {"success"=>false, "error-codes"=>["invalid-input-response"], "messages"=>[], "metadata"=>{"result_with_testing_key"=>true}}

    if !result["success"]
      Rails.logger.warn("#{self.class.name}: Cloudflare Turnstile validation failed (#{request.remote_ip}, #{request.user_agent}): #{result}: #{params["dest"]}")
      render plain: "Denied due to traffic and bot controls. If this check is intefering with your use, please contact us at digital@sciencehistory.org", status: 403
    end
  rescue HTTP::Error, JSON::ParserError => e
    # probably an http timeout? or something weird.
    Rails.logger.warn("#{self.class.name}: Cloudflare turnstile validation error (#{request.remote_ip}, #{request.user_agent}): #{e}: #{response&.body}")
    render plain: "Denied due to traffic and bot controls. If this check is intefering with your use, please contact us at digital@sciencehistory.org", status: 403
  end
end
