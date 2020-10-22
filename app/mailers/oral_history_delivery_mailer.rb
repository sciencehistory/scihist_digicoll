class OralHistoryDeliveryMailer < ApplicationMailer

  def oral_history_delivery_email
    raise ArgumentError.new("Required params[:request] missing") unless request.present?
    raise ArgumentError.new("Required patron email missing") unless request.patron_email.present?
    raise RuntimeError.new("Required from email address missing") unless from_address.present?
    mail( from: from_address, to: to_address, subject: subject, content_type: "text/html")
  end

  def request
    @request ||= params[:request]
  end

  def from_address
    ScihistDigicoll::Env.lookup(:no_reply_email_address)
  end

  def to_address
    request.patron_email
  end

  # Note: any value greater than 604800 will raise an exception.
  # See https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Presigner.html
  def how_long_urls_will_be_valid
    1.week.to_i - 10
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
    work.members.order(:position).select {|x| x.is_a? Asset}
  end

  def asset_links
    assets.map do |asset|
      url = asset.file.url(
        public: false,
        expires_in: how_long_urls_will_be_valid,
        response_content_type: asset.content_type,
        response_content_disposition: ContentDisposition.format(
          disposition: "inline",
          filename: DownloadFilenameHelper.filename_for_asset(asset)
        )
      )
      { text: asset.title, url: url }
    end
  end

  def subject
    "Science History Institute: files from #{work.title}"
  end

  def hostname
    ScihistDigicoll::Env.lookup!(:app_url_base)
  end

  def work_url
    @work_url ||= "#{hostname}#{Rails.application.routes.url_helpers.work_path(work.friendlier_id)}"
  end

  def work_link
    "<a href=\"#{work_url}\">#{work.title}</a>".html_safe
  end
end