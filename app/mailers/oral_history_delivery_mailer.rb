class OralHistoryDeliveryMailer < ApplicationMailer

  def oral_history_delivery_email
    raise ArgumentError.new("Required params[:request] missing") unless request.present?
    raise ArgumentError.new("Required patron email missing") unless request.patron_email.present?
    mail(to: to_address, subject: subject, content_type: "text/html")
  end

  def request
    @request ||= params[:request]
  end

  def to_address
    request.patron_email
  end

  # Note: any value greater than 604800 will raise an exception.
  # See https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Presigner.html
  def asset_expiration_time
    1.week.to_i
  end


  def created_at
    request.created_at
  end

  def patron_name
    request.patron_name
  end

  def work
    request.work
  end

  def assets
    WorkFileListShowDecorator.new(work).available_by_request_assets.sort_by(&:position)
  end

  def download_label(asset)
    details = []
    details << ScihistDigicoll::Util.humanized_content_type(asset.content_type) if asset.content_type.present?
    details << ScihistDigicoll::Util.simple_bytes_to_human_string(asset.size) if asset.size.present?
    if details.present?
      "#{asset.title} (#{details.join(" — ")})"
    else
      asset.title
    end
  end

  def download_url(asset)
    asset.file.url(
      public: false,
      expires_in: asset_expiration_time,
      response_content_type: asset.content_type,
      response_content_disposition: ContentDisposition.format(
        disposition: "inline",
        filename: DownloadFilenameHelper.filename_for_asset(asset)
      )
    )
  end

  def subject
    "Science History Institute: files from #{work.title}"
  end

  def hostname
    ScihistDigicoll::Env.lookup!(:app_url_base)
  end

end