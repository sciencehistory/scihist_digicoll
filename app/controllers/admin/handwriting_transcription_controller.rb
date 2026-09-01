class Admin::HandwritingTranscriptionController < AdminController
  before_action :set_work

  def request_handwriting_transcription
    unless ScihistDigicoll::Env.lookup(:gemini_htr_transcripts_feature_flag)
      redirect_to(
        admin_work_path(@work),
        flash: { notice: "Automatic handwriting transcription isn't available." },
        anchor: "tab=nav-ocr"
      )
    end

    GeminiHandwritingTranscriptionService.new(work: @work).call

    redirect_to(
      admin_work_path(@work),
      flash: { notice: "Handwriting transcription completed." },
      anchor: "tab=nav-ocr"
    )
  rescue GeminiHandwritingTranscriptionService::Error => e
    redirect_to(
      admin_work_path(@work),
      flash: { alert: e.message },
      anchor: "tab=nav-ocr"
    )
  end

  private

  def set_work
    @work = Work.find_by!(friendlier_id: params[:work_id])
  end
end