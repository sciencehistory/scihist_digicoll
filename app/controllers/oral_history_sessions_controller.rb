# We let OH requesters log in with magic links, using tokens
# generated from Patron#generates_token_for(:auto_login), then devise handles the session.
#
# The same emails also include a short code, which can be entered instead, see PatronSignInCodeFlow.
class OralHistorySessionsController < ApplicationController
  include PatronSignInCodeFlow

  # full pages for login and code entry, just extra guards we really don't want bots in our
  # patron sessions.
  bot_challenge only: [:new, :code_form]

  rate_limit to: 10, within: 15.minutes, only: [:create, :verify_code], with: -> {
    redirect_to new_oral_history_session_path(return_to: safe_return_to(params[:return_to])),
      flash: { auto_link_message: "Too many attempts. Please wait a few minutes and try again." }
  }

  # GET /oral_history_session/login/$TOKEN(?return_to=/local/path)
  #
  # Log someone in by magic link TOKEN, from clicking a link in email.
  def login
    patron = Patron.find_by_token_for(:auto_login, params[:token])
    if patron.present?
      sign_in_patron_and_redirect(patron)
    else
      # invalid/expired/missing token
      redirect_to new_oral_history_session_path, flash: { auto_link_message: "Sorry, your link has expired or is not valid. Please enter your email, and we'll send you a new one."}
    end
  end

  # GET /oral_history_session/new
  #
  # Form to request an emailed link
  def new
    # fix a stale signed-in flag, eg after session_token rotation; patron-only pages redirect here
    cookies.delete(Patron::SIGNED_IN_FLAG_COOKIE) unless current_patron
  end

  # POST /oral_history_session/create
  #
  # Sends an emailed link and code
  def create
    patron = Patron.find_by(email: email_param)

    if patron.present?
      OhSessionMailer.with(patron: patron, return_to: safe_return_to(params[:return_to])).sign_in_email.deliver_later

      show_sign_in_code_form(patron, return_to: safe_return_to(params[:return_to]),
        message: "We've emailed a sign-in link and code to #{patron.email}.")
    else
      redirect_to new_oral_history_session_path(return_to: safe_return_to(params[:return_to])), flash: { auto_link_message: "Sorry, we have no email on record for #{params[:email]}. Please check your entry."}
    end
  end

  # GET /oral_history_session/code(?return_to=/local/path)
  #
  # Form to enter the emailed code, for the email kept in session
  def code_form
    @sign_in_code_email = session[SESSION_KEY]

    unless @sign_in_code_email
      redirect_to new_oral_history_session_path(return_to: safe_return_to(params[:return_to]))
    end
  end

  # POST /oral_history_session/code
  def verify_code
    patron = session[SESSION_KEY].present? && Patron.find_by(email: session[SESSION_KEY])

    if patron && patron.consume_sign_in_code!(params[:code])
      session.delete(SESSION_KEY)
      sign_in_patron_and_redirect(patron)
    else
      redirect_to code_oral_history_session_path(return_to: safe_return_to(params[:return_to])),
        flash: { auto_link_message: "Sorry, that code is incorrect or has expired. Please try again, or request a new one." }
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

  # confirms too, since they got the link or code from the email
  def sign_in_patron_and_redirect(patron)
    patron.confirm! unless patron.confirmed?

    # don't let an old timed-out session abort a fresh login
    request.env["devise.skip_timeout"] = true
    patron.remember_me = true
    sign_in(:patron, patron)
    redirect_to (safe_return_to(params[:return_to]) || patron_account_path), allow_other_host: false
  end

  def email_param
    params.dig(:email) or raise ActionController::ParameterMissing.new(:email)
  end

end
