# PUBLIC FACING
#
# Patron registration for automatic_request oral histories. Registering emails a link that
# confirms the patron and returns them to the work. Confirmed patrons get access to all
# automatic_request oral histories.
#
# reviewed_request oral histories use OralHistoryRequestsController instead.
class OralHistoryRegistrationsController < ApplicationController
  include OralHistoryRequestFormMemoryHelper

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

    @patron = Patron.find_or_create_from_form(**registration_params.to_h.symbolize_keys)

    unless @patron.persisted?
      render :new
      return
    end

    if @patron.confirmed?
      OhSessionMailer.with(patron: @patron, return_to: work_path(@work.friendlier_id)).sign_in_email.deliver_later
      return_status("You are already registered. We've sent an email to #{@patron.email} with a sign-in link.")
    else
      OhSessionMailer.with(patron: @patron, work: @work).registration_email.deliver_later
      return_status("Thank you for registering. We've sent an email to #{@patron.email}. Click the link in it to confirm your email address and get access.")
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

  # signing in confirms, so a signed-in patron is already registered
  def redirect_if_signed_in
    if current_patron
      return_status("You are already registered and signed in.")
    end
  end

  # back to the work: an alert in the modal for JS requests, otherwise a redirect with flash
  def return_status(message)
    if request.xhr?
      render partial: "oral_history_requests/alert", layout: false, locals: { alert_type: "success", message: message }
    else
      redirect_to work_path(@work.friendlier_id), flash: { success: message }
    end
  end

  def registration_params
    params.require(:patron).permit(:email, :name, :institution, :registration_reason)
  end
end
