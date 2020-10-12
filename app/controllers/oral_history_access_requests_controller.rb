# PUBLIC FACING
# Staff-facing actions are in app/controllers/admin/oral_history_access_requests_controller.rb
class OralHistoryAccessRequestsController < ApplicationController

  # GET /works/4j03d097t/request_oral_history_access
  def new
    @work = Work.find_by_friendlier_id(params['work_friendlier_id'])
    check_assets_available_by_request
    @oral_history_access_request = Admin::OralHistoryAccessRequest.new
  end

  # POST "/request_oral_history_access"
  def create
    work_friendlier_id = params['admin_oral_history_access_request'].delete('work_friendlier_id')
    @work = Work.find_by_friendlier_id(work_friendlier_id)
    check_assets_available_by_request
    @oral_history_access_request = Admin::OralHistoryAccessRequest.new(oral_history_access_request_params)
    @oral_history_access_request.work = @work
    if @oral_history_access_request.save
      redirect_to work_path(work_friendlier_id), notice: 'Your request has been logged.'
    else
     render :new
    end
  end

private
  def set_oral_history_access_request
    @oral_history_access_request = Admin::OralHistoryAccessRequest.find(params[:id])
  end

  def oral_history_access_request_params
    params.require(:admin_oral_history_access_request).permit(
      :work_friendlier_id, :patron_name, :patron_email,
      :patron_institution, :intended_use, :status, :notes)
  end

  def check_assets_available_by_request
    return if WorkFileListShowDecorator.new(@work).available_by_request_assets.present?
    raise RuntimeError, "You can't request this work using this form: it's either freely available or not available to the public."
  end

end