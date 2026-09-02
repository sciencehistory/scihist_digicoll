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

    HandwritingTranscriptionJob.perform_later(@work)

    redirect_to(
      admin_work_path(@work),
      flash: { notice: "Requesting a transcript. Check back in a few minutes!" },
      anchor: "tab=nav-ocr"
    )
  end

  private

  def set_work
    @work = Work.find_by!(friendlier_id: params[:work_id])
  end
end