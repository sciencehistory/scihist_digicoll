# We let OH requesters log in with magic links, using tokens
# generated from Patron#generates_token_for(:auto_login)
class OralHistorySessionsController < ApplicationController
  SESSION_COOKIE_NAME = "scihist_oh_user"
  SESSION_KEY = "patron_id"
  SESSION_EXPIRE_PERIOD = 30.days


  # @param request [ActionDispatch::Request]
  # @param patron [Patron]
  def self.store_current_patron(request:, patron:)
    request.cookie_jar.encrypted[SESSION_COOKIE_NAME] = {
      value: JSON.generate({ SESSION_KEY => patron.id }),
      expires: SESSION_EXPIRE_PERIOD
    }
  end

  # @param request [ActionDispatch::Request]
  # @return [Patron, nil]
  def self.fetch_current_patron(request:, reset_expiration_window: false)
    if request.cookie_jar.encrypted[SESSION_COOKIE_NAME].present?
      id = JSON.parse(request.cookie_jar.encrypted[SESSION_COOKIE_NAME])[SESSION_KEY]
      Patron.find_by(id: id).tap do |patron|
        if patron && reset_expiration_window
          # push expiration to be further back
          store_current_patron(request: request, patron: patron)
        end
      end
    else
      nil
    end
  rescue JSON::ParserError => e
    Rails.logger.error("#{self.name}: #{e}")
    return nil
  end

  # @param request [ActionDispatch::Request]
  def self.sign_out_current_patron(request:)
    request.cookie_jar.delete SESSION_COOKIE_NAME
  end

  # GET /oral_history_session/login/$TOKEN
  #
  # Actually logs someone in
  def login
    patron = Patron.find_by_token_for(:auto_login, params[:token])
    if patron.present?
      self.class.store_current_patron(request: request, patron: patron)
      redirect_to oral_history_requests_path
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
      OhSessionMailer.with(patron: patron).link_email.deliver_later

      redirect_to helpers.root_path, notice: "A sign-in link for your Oral Histories requests has been emailed to #{patron.email}"
    else
      redirect_to new_oral_history_session_path, flash: { auto_link_message: "Sorry, we have no email on record for #{params[:email]}. Please check your entry."}
    end
  end

  # DELETE /oral_history_session
  #
  # Log out!
  def destroy
    self.class.sign_out_current_patron(request: request)

    redirect_to helpers.root_path, :flash => { :success => "You have been signed out of your Oral History requests. You can sign in again from the link in your email, or by making another request." }
  end

  private

  def email_param
    params.dig(:email) or raise ActionController::ParameterMissing.new(:email)
  end

end
