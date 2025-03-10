# Used for delivering actual files (old style), or with new stle for delivering
# notice of approval/rejection, and magic login link to see your requests.
class OralHistoryDeliveryMailer < ApplicationMailer
  default from: ScihistDigicoll::Env.lookup!(:oral_history_email_address), bcc: ScihistDigicoll::Env.lookup!(:oral_history_email_address)

  # Note: any value greater than 604800 will raise an exception.
  # See https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Presigner.html
  ASSET_EXPIRATION_TIME = 1.week.to_i

  def oral_history_delivery_email
    raise ArgumentError.new("Required params[:request] missing") unless oh_request.present?
    raise ArgumentError.new("Required patron email missing") unless oh_request.requester_email.present?
    mail(to: to_address, subject: "Science History Institute: files from #{work.title}", content_type: "text/html")
  end

  # NEW style, where we send them a link to their in-browser 'dashboard' instead of
  # links to files
  def approved_with_session_link_email
    raise ArgumentError.new("Required params[:request] missing") unless oh_request.present?
    raise ArgumentError.new("Required request.oral_history_requester missing") unless oh_request.oral_history_requester.present?
    raise ArgumentError.new("params[:request] must be approved or automatic but was #{oh_request.delivery_status}") unless oh_request.delivery_status_approved? || oh_request.delivery_status_automatic?

    mail(to: to_address, subject: "Science History Institute Oral History Request: Approved: #{work.title}", content_type: "text/html")
  end

  def rejected_with_session_link_email
    raise ArgumentError.new("Required params[:request] missing") unless oh_request.present?
    raise ArgumentError.new("Required request.oral_history_requester missing") unless oh_request.oral_history_requester.present?
    raise ArgumentError.new("params[:request] must be rejected but was #{oh_request.delivery_status}") unless oh_request.delivery_status_rejected?

    mail(to: to_address, subject: "Science History Institute Oral History Request: #{work.title}", content_type: "text/html")
  end

  def oh_request
    @oh_request ||= params[:request]
  end

  # warning `message` is a reserved method and param name for ActionMailer, don't override it!
  #
  # Old style we pass a message in as param, but new style we use the message that's state in the request
  # please
  def custom_message
    @custom_message ||= params[:request].notes_from_staff.presence || params[:custom_message]
  end

  def to_address
    oh_request.requester_email
  end

  def download_by_human_readable
    I18n.l(Date.today + 6.days, format: :expiration_date)
  end

  def created_at
    oh_request.created_at
  end

  def patron_name
    oh_request.patron_name
  end

  def work
    oh_request.work
  end

  def assets
    WorkFileListShowComponent.new(work).available_by_request_assets.sort_by(&:position)
  end

  def hostname
    ScihistDigicoll::Env.lookup!(:app_url_base)
  end

  def login_magic_link
    token = oh_request.oral_history_requester.generate_token_for(:auto_login)

    login_oral_history_session_url(token)
  end
  helper_method :login_magic_link
end
