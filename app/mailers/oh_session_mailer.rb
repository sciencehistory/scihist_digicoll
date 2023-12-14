class OhSessionMailer < ApplicationMailer

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.oh_session_mailer.link_email.subject
  #
  def link_email
    @requester_email = params[:requester_email] or raise ArgumentError.new("missing required params[:requester_email]")

    mail to: @requester_email.email, subject: "Sign-in to Science History Insitute Oral Histories Requests"
  end

  def login_magic_link
    token = @requester_email.generate_token_for(:auto_login)

    login_oral_history_session_url(token)
  end
  helper_method :login_magic_link
end
