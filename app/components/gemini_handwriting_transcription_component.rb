# On the admin work page's text extraction tab, shows the status of the work's Gemini
# handwriting transcription request, with buttons for the less frequent actions that
# Admin::HandwritingTranscriptionController handles: replacing a finished request with a
# new one, and deleting the transcription.
#
# Only shown when the gemini_htr_transcripts_feature_flag is on, and the work is in
# handwriting transcription mode or still has a request.
class GeminiHandwritingTranscriptionComponent < ApplicationComponent
  attr_reader :work

  delegate :can?, to: :helpers

  def initialize(work)
    @work = work
  end

  def render?
    ScihistDigicoll::Env.lookup(:gemini_htr_transcripts_feature_flag) &&
      (work.handwriting_transcription_mode? || transcription_request.present?)
  end

  def transcription_request
    work.handwriting_transcription_request
  end

  def eligibility_problems
    @eligibility_problems ||= GeminiHandwritingTranscriptionService.new(work: work).work_eligibility_problems
  end

  def status_message
    if transcription_request.present?
      transcription_request.status_message
    else
      "A handwriting transcription will be requested soon."
    end
  end

  # Once a request has been made, its status says what happened, so we only warn beforehand.
  def eligibility_warning
    return nil if transcription_request.present? || eligibility_problems.empty?

    "This work isn't eligible for handwriting transcription, because " \
      "#{eligibility_problems.to_sentence}. The request will be recorded as failed, " \
      "without being sent to Gemini."
  end

  def formatted_start_time
    return nil if transcription_request&.start_time.blank?

    l(transcription_request.start_time, format: :admin_compact)
  end

  # A finished request, whether it succeeded or failed, can be replaced with a new one.
  def offer_new_request?
    work.handwriting_transcription_mode? && transcription_request&.finished?
  end

  def offer_delete?
    transcription_request&.finished?
  end

  # Replacing a successful transcription throws it away, and costs money.
  def new_request_confirm_message
    if transcription_request.success?
      "This will delete the current transcript and request a new one from Gemini. Are you sure?"
    end
  end
end
