class Admin::HandwritingTranscriptionController < AdminController
  before_action :set_work

  def request_handwriting_transcription
    unless ScihistDigicoll::Env.lookup(:gemini_htr_transcripts_feature_flag)
      return redirect_to(
        admin_work_path(@work, anchor: "tab=nav-ocr"),
        flash: { notice: "Automatic handwriting transcription isn't available." }
      )
    end

    HandwritingTranscriptionJob.perform_later(@work)

    redirect_to(
      admin_work_path(@work, anchor: "tab=nav-ocr"),
      flash: { notice: "Requesting a transcript. Check back in a few minutes!" }
    )
  end

  private

  def set_work
    @work = Work.find_by!(friendlier_id: params[:work_id])
  end
end