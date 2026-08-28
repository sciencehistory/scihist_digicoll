class Admin::HandwritingTranscriptionController < AdminController
  before_action :set_work

  def request_handwriting_transcription
    GeminiHandwritingTranscriptionService.new(
      work: @work,
      assets: assets
    ).call

    redirect_to(
      admin_work_path(@work),
      flash: {
        notice: "A transcript of this work has been requested."
      },
      anchor: "tab=nav-ocr"
    )
  rescue GeminiHandwritingTranscriptionService::MissingDerivativeError => e
    redirect_to(
      admin_work_path(@work),
      flash: {
        notice: e.message
      },
      anchor: "tab=nav-ocr"
    )
  end

  private

  def set_work
    @work = Work.find_by_friendlier_id(params[:work_id])
  end

  def assets
    @assets ||= @work.
      members.
      includes(:leaf_representative).
      where(published: true).
      order(:position).
      select do |m|
        m.leaf_representative.content_type == "image/jpeg" ||
          m.leaf_representative&.file_derivatives(:download_full)
      end
  end
end