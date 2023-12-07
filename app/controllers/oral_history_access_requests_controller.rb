# PUBLIC FACING
# Staff-facing actions are in app/controllers/admin/oral_history_access_requests_controller.rb
class OralHistoryAccessRequestsController < ApplicationController
  include OralHistoryRequestFormMemoryHelper

  # GET /works/4j03d09fr7t/request_oral_history_access
  def new
    @work = load_work(params['work_friendlier_id'])
    @oral_history_access_request = Admin::OralHistoryAccessRequest.new(work: @work)
  end

  # POST "/request_oral_history_access"
  def create
    @work = load_work(params['admin_oral_history_access_request'].delete('work_friendlier_id'))

    # note `create_or_find_by` is the version with fewer race conditions, to make
    # this record if it doesn't already exist.
    @oral_history_access_request = Admin::OralHistoryAccessRequest.new(
      oral_history_access_request_params.merge(
        work: @work,
        oral_history_requester_email: (Admin::OralHistoryRequesterEmail.create_or_find_by(email: patron_email_param) if patron_email_param.present?)
      )
    )

    if @oral_history_access_request.save
      if @work.oral_history_content.available_by_request_automatic?
        @oral_history_access_request.update!(delivery_status: "automatic")

        OralHistoryDeliveryMailer.
          with(request: @oral_history_access_request).
          oral_history_delivery_email.
          deliver_later

        redirect_to work_path(@work.friendlier_id), notice: "Check your email! We are sending you links to the files you requested, to #{@oral_history_access_request.patron_email}."
      else # manual review
        OralHistoryRequestNotificationMailer.
          with(request: @oral_history_access_request).
          notification_email.
          deliver_later

        redirect_to work_path(@work.friendlier_id), notice: "Thank you for your interest. Your request will be reviewed, usually within 3 business days, and we'll email you at #{@oral_history_access_request.patron_email}"
      end
    else
     render :new
    end

    # write entries to a cookie to pre-fill form next time; every time we write
    # it will bump the TTL expiration too, so they get another day until it expires.
    # Make sure to include the separate patron_eamil
    oral_history_request_form_entry_write(
      oral_history_access_request_params.merge(patron_email: patron_email_param).to_h
    )
  end

private
  def oral_history_access_request_params
    params.require(:admin_oral_history_access_request).permit(
      :work_friendlier_id, :patron_name,
      :patron_institution, :intended_use, :status, :notes)
  end

  def patron_email_param
    params[:patron_email] or raise ActionController::ParameterMissing.new(:patron_email)
  end

  def load_work(friendlier_id)
    work = Work.find_by_friendlier_id!(friendlier_id)
    #   # No sense showing this form for a work that is either freely available
    #   # or locked down. (This should never happen, but just in case.)
    unless WorkFileListShowComponent.new(work).available_by_request_assets.present?
      Rails.logger.warn("/works/#{work.friendlier_id}/request_oral_history_access: Can't request oral history access, no eligible files.")

      # ActionController::RoutingError will just tell Rails to render standard 404.
      raise ActionController::RoutingError.new('Not Found')
    end
    work
  end
end
