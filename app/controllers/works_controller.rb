# FRONT-END controller for public Works views -- mostly just the #show action.
# Not to be confused with admin/works_controller for staff/management/edit views.
class WorksController < ApplicationController
  before_action :set_work, :check_auth

  def show
    respond_to do |format|
      format.html
      format.ris {
        send_data RisSerializer.new(@work).to_ris,
          disposition: 'attachment',
          filename: ris_download_filename,
          type: :ris
      }
    end
  end

  private

  # The download_filename helper specializes
  # in originals and derivatives, and the RIS download
  # isn't really either, so this is a bit more complicated
  # than  it used to be.
  def ris_download_filename
    name_with_ext = DownloadFilenameHelper.
      filename_for_asset(@work.representative)
    name_without_ext = Pathname.
      new(name_with_ext).sub_ext("").to_s
    "#{name_without_ext}.ris"
  end

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
