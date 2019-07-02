# FRONT-END controller for public Works views -- mostly just the #show action.
# Not to be confused with admin/works_controller for staff/management/edit views.
class WorksController < ApplicationController
  before_action :set_work, :check_auth

  def show
    respond_to do |format|
      format.html
      format.ris {
        send_data RisSerializer.new(@work).to_ris,
          disposition: 'inline',
          type: "application/x-research-info-systems"
      }
    end
  end

  private

  def set_work
    @work = Work.find_by_friendlier_id!(params[:id])
  end

  def check_auth
    authorize! :read, @work
  end

  def decorator
    @decorator = WorkShowDecorator.new(@work)
  end
  helper_method :decorator
end
