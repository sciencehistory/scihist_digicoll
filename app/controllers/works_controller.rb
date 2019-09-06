# FRONT-END controller for public Works views -- mostly just the #show action.
# Not to be confused with admin/works_controller for staff/management/edit views.
class WorksController < ApplicationController
  before_action :set_work, :check_auth

  def show
    respond_to do |format|
      format.html {
        render template: template
      }

      format.xml {
        render body: WorkOaiDcSerialization.new(@work).to_oai_dc, type: :xml
      }

      format.ris {
        send_data RisSerializer.new(@work).to_ris,
          disposition: 'attachment',
          filename: DownloadFilenameHelper.ris_download_name(@work),
          type: :ris
      }
    end
  end

  def viewer_images_info
    render json: ViewerMemberInfoSerializer.new(@work).as_hash
  end

  private

  def decorator
    @decorator ||= if has_audio_member?
      AudioWorkShowDecorator.new(@work)
    else
      WorkShowDecorator.new(@work)
    end
  end
  helper_method :decorator

  def has_audio_member?
    @work.members.
      where(published: true).
      any? { | x| x.leaf_representative&.content_type&.start_with?("audio/") }
  end

  def set_work
    @work = Work.find_by_friendlier_id!(params[:id])
  end

  def check_auth
    authorize! :read, @work
  end

  def template
    @template ||= decorator.view_template
  end

end
