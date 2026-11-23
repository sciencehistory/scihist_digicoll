# PUBLIC FACING
#
# Patron registration for automatic_request oral histories. Registering emails a link that
# confirms the patron and returns them to the work. Confirmed patrons get access to all
# automatic_request oral histories.
#
# reviewed_request oral histories use OralHistoryRequestsController instead.
class OralHistoryRegistrationsController < ApplicationController
  include OralHistoryRequestFormMemoryHelper
  include PatronSignInCodeFlow

  before_action :set_work
  before_action :redirect_if_signed_in

  # GET /works/:work_friendlier_id/register_oral_history
  def new
    @patron = Patron.new
  end

  # POST /register_oral_history
  def create
    oral_history_request_form_entry_write(
      "patron_name" => registration_params[:name],
      "patron_email" => registration_params[:email],
      "patron_institution" => registration_params[:institution],
      "registration_reason" => registration_params[:registration_reason]
    )

    # before anything that could send an email
    unless turnstile_form_protection.passed?
      @patron = Patron.new(registration_params)
      @patron.errors.add(:base, TurnstileFormProtection::FAILED_MESSAGE)
      render :new
      return
    end

    @patron = Patron.find_or_create_from_form(**registration_params.to_h.symbolize_keys)

    unless @patron.persisted?
      render :new
      return
    end

    if @patron.confirmed?
      OhSessionMailer.with(patron: @patron, return_to: work_path(@work.friendlier_id)).sign_in_email.deliver_later
      show_sign_in_code_form(@patron, return_to: work_path(@work.friendlier_id),
        message: "You are already registered. We've sent an email to #{@patron.email} with a sign-in link and code.")
    else
      OhSessionMailer.with(patron: @patron, work: @work).registration_email.deliver_later
      show_sign_in_code_form(@patron, return_to: work_path(@work.friendlier_id),
        message: "Thank you for registering. We've sent an email to #{@patron.email}. Click the link in it, or enter the code from it, to confirm your email address and get access.")
    end
  end

  private

  # 404 unless it's an automatic_request oral history with files to register for
  def set_work
    @work = Work.find_by_friendlier_id!(params[:work_friendlier_id])

    unless @work.oral_history_content&.availability_automatic_request? &&
        WorkFileListShowComponent.new(@work).available_by_request_assets.present?
      raise ActionController::RoutingError.new("Not Found")
    end
  end

  # signing in confirms, so a signed-in patron is already registered.
  # Back to the work: an alert in the modal for JS requests, otherwise a redirect with flash.
  def redirect_if_signed_in
    return unless current_patron

    message = "You are already registered and signed in."
    if request.xhr?
      render partial: "oral_history_requests/alert", layout: false, locals: { alert_type: "success", message: message, title: "Register for Oral History Access" }
    else
      redirect_to work_path(@work.friendlier_id), flash: { success: message }
    end
  end

  def registration_params
    params.require(:patron).permit(:email, :name, :institution, :registration_reason)
  end

  # one per request, for the form partial and the submit check
  def turnstile_form_protection
    @turnstile_form_protection ||= TurnstileFormProtection.new(
      token: params["cf-turnstile-response"],
      remote_ip: request.remote_ip,
      bot_challenge_passed: BotChallengePage::BotChallengePageController._bot_detect_passed_good?(self)
    )
  end
  helper_method :turnstile_form_protection
end
