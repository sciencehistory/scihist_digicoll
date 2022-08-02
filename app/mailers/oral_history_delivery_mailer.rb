class OralHistoryDeliveryMailer < ApplicationMailer
  default from: ScihistDigicoll::Env.lookup!(:oral_history_email_address), bcc: ScihistDigicoll::Env.lookup!(:oral_history_email_address)

  # Note: any value greater than 604800 will raise an exception.
  # See https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Presigner.html
  ASSET_EXPIRATION_TIME = 1.week.to_i

  def oral_history_delivery_email
    raise ArgumentError.new("Required params[:request] missing") unless request.present?
    raise ArgumentError.new("Required patron email missing") unless request.patron_email.present?
    mail(to: to_address, subject: subject, content_type: "text/html")
  end

  def request
    @request ||= params[:request]
  end

  # warning `message` is a reserved method and param name for ActionMailer, don't override it!
  def custom_message
    @custom_message ||= params[:custom_message]
  end

  def to_address
    request.patron_email
  end

  def download_by_human_readable
    I18n.l(Date.today + 6.days, format: :expiration_date)
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
    WorkFileListShowComponent.new(work).available_by_request_assets.sort_by(&:position)
  end

  def subject
    "Science History Institute: files from #{work.title}"
  end

  def hostname
    ScihistDigicoll::Env.lookup!(:app_url_base)
  end

end
