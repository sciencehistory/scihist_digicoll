# FRONT-END controller for public Works views -- mostly just the #show action.
# Not to be confused with admin/works_controller for staff/management/edit views.
class WorksController < ApplicationController
  before_action :set_work, :set_decorator_and_template, :check_auth

  def show
    respond_to do |format|
      format.html {
        render template: @template
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

  def set_decorator_and_template
    if AudioWorkShowDecorator.show_playlist?(@work)
      then
        @decorator = AudioWorkShowDecorator.new(@work)
        @template  = 'works/show_with_audio'
      else
        @decorator = WorkShowDecorator.new(@work)
        @template  = 'works/show'
      end
  end

  def set_work
    @work = Work.find_by_friendlier_id!(params[:id])
  end

  def check_auth
    authorize! :read, @work
  end

  def decorator
    @decorator
  end
  helper_method :decorator
end
