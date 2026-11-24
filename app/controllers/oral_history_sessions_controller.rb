# We let OH requesters log in with magic links, using tokens
# generated from Patron#generates_token_for(:auto_login), then devise handles the session.
class OralHistorySessionsController < ApplicationController
  # GET /oral_history_session/login/$TOKEN(?return_to=/local/path)
  #
  # Actually logs someone in, and confirms them, since they clicked an emailed link.
  def login
    patron = Patron.find_by_token_for(:auto_login, params[:token])
    if patron.present?
      patron.confirm! unless patron.confirmed?

      # don't let an old timed-out session abort a fresh login
      request.env["devise.skip_timeout"] = true
      patron.remember_me = true
      sign_in(:patron, patron)
      redirect_to (safe_return_to || patron_account_path), allow_other_host: false
    else
      # invalid/expired/missing token
      redirect_to new_oral_history_session_path, flash: { auto_link_message: "Sorry, your link has expired or is not valid. Please enter your email, and we'll send you a new one."}
    end
  end

  # GET /oral_history_session/new
  #
  # Form to request an emailed link
  def new

  end

  # POST /oral_history_session/create
  #
  # Sends an emailed links
  def create
    patron = Patron.find_by(email: email_param)

    if patron.present?
      OhSessionMailer.with(patron: patron).sign_in_email.deliver_later

      redirect_to helpers.root_path, notice: "A sign-in link for Science History Institute Oral Histories has been emailed to #{patron.email}"
    else
      redirect_to new_oral_history_session_path, flash: { auto_link_message: "Sorry, we have no email on record for #{params[:email]}. Please check your entry."}
    end
  end

  # DELETE /oral_history_session
  #
  # Log out!
  def destroy
    sign_out(:patron)

    redirect_to helpers.root_path, :flash => { :success => "You have been signed out of Oral Histories. You can sign in again from the link in any email we have sent you." }
  end

  private

  def email_param
    params.dig(:email) or raise ActionController::ParameterMissing.new(:email)
  end

  # only a local path, so the link can't be used to redirect off-site
  def safe_return_to
    path = params[:return_to]
    path if path.is_a?(String) && path.start_with?("/") && !path.start_with?("//") && !path.include?("\\")
  end

end
