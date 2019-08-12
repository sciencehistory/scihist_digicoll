# FRONT-END controller for public Works views -- mostly just the #show action.
# Not to be confused with admin/works_controller for staff/management/edit views.
class WorksController < ApplicationController
  before_action :set_work, :check_auth

  def show
    respond_to do |format|
      format.html {
        render template: 'works/show'
      }
      format.ris {
        send_data RisSerializer.new(@work).to_ris,
          disposition: 'attachment',
          filename: DownloadFilenameHelper.ris_download_name(@work),
          type: :ris
      }
    end
  end

  private

  def decorator
    @decorator ||= if AudioWorkShowDecorator.show_playlist?(@work)
      AudioWorkShowDecorator.new(@work)
    else
      WorkShowDecorator.new(@work)
    end
  end
  helper_method :decorator

  def set_work
    @work = Work.find_by_friendlier_id!(params[:id])
  end

  def check_auth
    authorize! :read, @work
  end


end
