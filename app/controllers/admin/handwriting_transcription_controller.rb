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

  def delete_handwriting_transcription
    GeminiHandwritingTranscriptionService.new(work: @work).remove_transcription!

    redirect_to(
      admin_work_path(@work, anchor: "tab=nav-ocr"),
      flash: { notice: "Transcript successfully deleted" }
    )
  rescue StandardError => e
    Rails.logger.error(
      "Could not delete handwriting transcript for work #{@work.friendlier_id}: #{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}"
    )

    redirect_to(
      admin_work_path(@work, anchor: "tab=nav-ocr"),
      flash: { error: "We were unable to delete the transcript. Please check the logs for more information." }
    )
  end

  private

  def set_work
    @work = Work.find_by!(friendlier_id: params[:work_id])
  end
end