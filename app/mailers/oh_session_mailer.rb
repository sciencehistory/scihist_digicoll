class OhSessionMailer < ApplicationMailer
  default from: ScihistDigicoll::Env.lookup!(:oral_history_email_address)

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.oh_session_mailer.sign_in_email.subject
  #
  def sign_in_email
    @patron = params[:patron] or raise ArgumentError.new("missing required params[:patron]")
    # optional local path to land on after sign-in
    @return_to = params[:return_to]

    # prevent gmail from threading multiple magic links in a thread, as gmail ends up hiding the more
    # recent one, which is bad maybe. Set a unique "references" header to avoid this
    # https://postmarkapp.com/blog/magic-links
    headers["references"] = "Unique-#{SecureRandom.hex(20)}"

    mail to: @patron.email, subject: "Your Science History Institute Oral Histories sign-in link"
  end

  # Sent on registering for automatic_request oral histories; the link confirms the patron
  # and returns them to the work they started from.
  def registration_email
    @patron = params[:patron] or raise ArgumentError.new("missing required params[:patron]")
    @work = params[:work] or raise ArgumentError.new("missing required params[:work]")

    # unique header so gmail doesn't thread (and hide) repeated sign-in emails, as in sign_in_email
    headers["references"] ="Unique-#{SecureRandom.hex(20)}"

    mail to: @patron.email, subject: "Confirm your Science History Institute registration"
  end

  def login_magic_link(return_to: nil)
    token = @patron.generate_token_for(:auto_login)

    login_oral_history_session_url(token, **{ return_to: return_to }.compact)
  end
  helper_method :login_magic_link

  def registered_oral_history_count
    Work.where(published: true).joins(:oral_history_content).
      where(oral_history_content: { availability_mode: "automatic_request" }).count
  end
  helper_method :registered_oral_history_count
end
