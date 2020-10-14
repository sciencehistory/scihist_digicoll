# PUBLIC FACING
# Staff-facing actions are in app/controllers/admin/oral_history_access_requests_controller.rb
class OralHistoryAccessRequestsController < ApplicationController

  before_action :set_work

  # GET /works/4j03d097t/request_oral_history_access
  def new
    @oral_history_access_request = cls.new
  end

  # POST "/request_oral_history_access"
  def create
    @oral_history_access_request = cls.new(oral_history_access_request_params)
    @oral_history_access_request.work = @work
    if @oral_history_access_request.save
      redirect_to work_path(@work.friendlier_id), notice: 'Your request has been logged.'
    else
     render :new
    end
  end

private
  def cls
    Admin::OralHistoryAccessRequest
  end

  def oral_history_access_request_params
    params.require(:admin_oral_history_access_request).permit(
      :work_friendlier_id, :patron_name, :patron_email,
      :patron_institution, :intended_use, :status, :notes)
  end

  def set_work
    if params['admin_oral_history_access_request'].present?
      @work_friendlier_id = params['admin_oral_history_access_request'].delete('work_friendlier_id')
    else
      @work_friendlier_id = params['work_friendlier_id']
    end
    @work = Work.find_by_friendlier_id(@work_friendlier_id)

    # No sense showing this form for a work that is either freely available
    # or locked down. (This should never happen, but just in case.)
    return if WorkFileListShowDecorator.new(@work).available_by_request_assets.present?
    raise RuntimeError, "You can't request this work using this form: it's either freely available or not available to the public."
  end


end