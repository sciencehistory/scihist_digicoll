# PUBLIC FACING
# Staff-facing actions are in app/controllers/admin/oral_history_access_requests_controller.rb
class OralHistoryAccessRequestsController < ApplicationController

  # GET /works/4j03d09fr7t/request_oral_history_access
  def new
    @work = load_work(params['work_friendlier_id'])
    @oral_history_access_request = Admin::OralHistoryAccessRequest.new
  end

  # POST "/request_oral_history_access"
  def create
    @work = load_work(params['admin_oral_history_access_request'].delete('work_friendlier_id'))
    @oral_history_access_request = Admin::OralHistoryAccessRequest.new(oral_history_access_request_params)
    @oral_history_access_request.work = @work
    if @oral_history_access_request.save
      OralHistoryDeliveryJob.
        new(@oral_history_access_request).
        perform_now
      redirect_to work_path(@work.friendlier_id), notice: "Check your email! The files you requested are being sent to you."
    else
     render :new
    end
  end

private
  def oral_history_access_request_params
    params.require(:admin_oral_history_access_request).permit(
      :work_friendlier_id, :patron_name, :patron_email,
      :patron_institution, :intended_use, :status, :notes)
  end

  def load_work(friendlier_id)
    work = Work.find_by_friendlier_id!(friendlier_id)
    #   # No sense showing this form for a work that is either freely available
    #   # or locked down. (This should never happen, but just in case.)
    unless WorkFileListShowDecorator.new(work).available_by_request_assets.present?
      raise RuntimeError, "You can't request this work using this form: it's either freely available or not available to the public."
    end
    work
  end
end