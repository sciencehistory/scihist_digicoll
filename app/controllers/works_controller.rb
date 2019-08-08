# FRONT-END controller for public Works views -- mostly just the #show action.
# Not to be confused with admin/works_controller for staff/management/edit views.
class WorksController < ApplicationController
  before_action :set_work, :check_auth

  def show
    respond_to do |format|
      format.html {
        render template: show_audio_player? ? 'works/show_with_audio' : 'works/show'
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

  # TODO this code is duplicated in the decorator.
  def show_audio_player?
    @show_audio_player ||= AudioWorkShowDecorator.has_audio_members?(@work)
  end

  def set_work
    @work = Work.find_by_friendlier_id!(params[:id])
  end

  def check_auth
    authorize! :read, @work
  end

  def decorator
    @decorator = show_audio_player? ? AudioWorkShowDecorator.new(@work) : WorkShowDecorator.new(@work)
  end
  helper_method :decorator
end
