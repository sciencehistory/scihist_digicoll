# We let OH requesters log in with magic links, using tokens
# generated from OralHistoryRequesterEmail#generates_token_for(:auto_login)
class OralHistorySessionsController < ApplicationController
  SESSION_COOKIE_NAME = "scihist_oh_user"
  SESSION_KEY = "oral_history_requester_id"
  SESSION_EXPIRE_PERIOD = 30.days


  # @param request [ActionDispatch::Request]
  # @param oral_history_requester [OralHistoryRequester]
  def self.store_oral_history_current_requester(request:, oral_history_requester:)
    request.cookie_jar.encrypted[SESSION_COOKIE_NAME] = {
      value: JSON.generate({ SESSION_KEY => oral_history_requester.id }),
      expires: SESSION_EXPIRE_PERIOD
    }
  end

  # @param request [ActionDispatch::Request]
  # @return [OralHistoryRequester, nil]
  def self.fetch_oral_history_current_requester(request:, reset_expiration_window: false)
    if request.cookie_jar.encrypted[SESSION_COOKIE_NAME].present?
      id = JSON.parse(request.cookie_jar.encrypted[SESSION_COOKIE_NAME])[SESSION_KEY]
      OralHistoryRequester.find_by(id: id).tap do |requester|
        if requester && reset_expiration_window
          # push expiration to be further back
          store_oral_history_current_requester(request: request, oral_history_requester: requester)
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
  def self.sign_out_current_requester(request:)
    request.cookie_jar.delete SESSION_COOKIE_NAME
  end

  # GET /oral_history_session/login/$TOKEN
  #
  # Actually logs someone in
  def login
    requester_email = OralHistoryRequester.find_by_token_for(:auto_login, params[:token])
    if requester_email.present?
      self.class.store_oral_history_current_requester(request: request, oral_history_requester: requester_email)
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
    requester_email = OralHistoryRequester.find_by(email: email_param)

    if requester_email.present?
      OhSessionMailer.with(requester_email: requester_email).link_email.deliver_later

      redirect_to helpers.root_path, notice: "A sign-in link for your Oral Histories requests has been emailed to #{requester_email.email}"
    else
      redirect_to new_oral_history_session_path, flash: { auto_link_message: "Sorry, we have no email on record for #{params[:email]}, check your entry?"}
    end
  end

  # DELETE /oral_history_session
  #
  # Log out!
  def destroy
    self.class.sign_out_current_requester(request: request)

    redirect_to helpers.root_path, notice: "You have been signed out of your Oral History requests. You can sign in again from the link in your email, or by making another request."
  end

  private

  def email_param
    params.dig(:email) or raise ActionController::ParameterMissing.new(:email)
  end

end
