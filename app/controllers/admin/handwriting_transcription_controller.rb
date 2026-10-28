# Less frequent handwriting transcription actions for a single work, beyond what the work
# metadata form does. (Choosing "handwriting transcription" as a work's text_extraction_mode
# is what normally requests a transcription; see WorkTranscriptionCreatorRemover.)
#
# * request_new_transcription: replaces a finished request -- whether it succeeded or failed --
#   with a fresh one. Removes any existing transcription first.
#
# * delete_transcription: removes the transcription and the request, and sets the work's
#   text_extraction_mode back to none (otherwise WorkTranscriptionCreatorRemover would just request
#   a new transcription).
class Admin::HandwritingTranscriptionController < AdminController
  before_action :set_work
  before_action :check_feature_flag

  # POST /admin/works/:id/request_new_handwriting_transcription
  def request_new_transcription
    transcription_request = @work.handwriting_transcription_request

    if !@work.handwriting_transcription_mode?
      return redirect_to_work(flash: { error: "This work's text extraction mode isn't set to handwriting transcription." })
    elsif transcription_request.nil?
      return redirect_to_work(flash: { error: "This work doesn't have a transcription request to replace yet." })
    elsif !transcription_request.finished?
      return redirect_to_work(flash: { error: "A transcription request for this work is still in progress." })
    end

    service.remove_transcription!
    service.queue_transcription!

    redirect_to_work(flash: { notice: "Requested a new transcript. Check back in a few minutes!" })
  end

  # DELETE /admin/works/:id/delete_handwriting_transcription
  def delete_transcription
    Work.transaction do
      @work.update!(text_extraction_mode: nil)
      service.remove_transcription!
    end

    redirect_to_work(flash: { notice: "Transcript deleted, and text extraction mode set to none." })
  rescue StandardError => e
    Rails.logger.error(
      "Could not delete handwriting transcript for work #{@work.friendlier_id}: #{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}"
    )

    redirect_to_work(flash: { error: "We were unable to delete the transcript. Please check the logs for more information." })
  end

  private

  def set_work
    @work = Work.find_by_friendlier_id!(params[:id])
    authorize! :update, @work
  end

  def check_feature_flag
    unless ScihistDigicoll::Env.lookup(:gemini_htr_transcripts_feature_flag)
      redirect_to_work(flash: { error: "Automatic handwriting transcription isn't available." })
    end
  end

  def service
    @service ||= GeminiHandwritingTranscriptionService.new(work: @work)
  end

  def redirect_to_work(flash:)
    redirect_to admin_work_path(@work, anchor: "tab=nav-ocr"), flash: flash
  end
end
