class Admin::GoogleArtsAndCultureDownloadsController < AdminController
  before_action :authenticate_user!

  def index

    @google_arts_and_culture_downloads = GoogleArtsAndCultureDownload.all
      .includes(:user)
      .page(params[:page]).per(20)
      .order(created_at: :desc)
  end
end