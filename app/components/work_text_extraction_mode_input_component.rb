# The text_extraction_mode radio buttons on the admin work form.
#
# When the gemini_htr_transcripts_feature_flag is on, also offers the option to request a
# handwriting transcription from Gemini -- including on the batch create and batch edit forms --
# and shows the status of any existing request. Works that aren't eligible for transcription can
# still choose the option, but get a warning: a request for them will be recorded as failed
# without being sent to Gemini.
#
# Saving the form with this option doesn't request the transcription directly; that's done
# by WorkTranscriptionCreatorRemover.
#
# Meant for use inside an existing simple_form form:
#
#     <%= render WorkTextExtractionModeInputComponent.new(form: f) %>
#
class WorkTextExtractionModeInputComponent < ApplicationComponent
  HANDWRITING_MODE = "handwriting_transcription"

  attr_reader :form

  def initialize(form:)
    @form = form
  end

  def call
    form.input :text_extraction_mode,
      label: "Text extraction mode (OCR, PDF, or handwriting)",
      collection: mode_options,
      as: :radio_buttons,
      hint: hint
  end

  def work
    form.object
  end

  def mode_options
    options = {
      "-none-" => "",
      "OCR (use for print text)" => "ocr",
      "PDF extraction" => "pdf_extraction"
    }
    options["Handwriting transcription"] = HANDWRITING_MODE if offer_handwriting_option?
    options
  end

  # Always offer the work's current mode, even if the feature flag is off, otherwise no
  # radio button would be checked and saving the form would silently clear the mode.
  def offer_handwriting_option?
    work.handwriting_transcription_mode? || feature_flag?
  end

  def feature_flag?
    ScihistDigicoll::Env.lookup(:gemini_htr_transcripts_feature_flag)
  end

  # Only for saved works: new works, and the blank works behind the batch create and batch
  # edit forms, have no images or request status to tell you about.
  def show_handwriting_info?
    feature_flag? && work.persisted?
  end

  def eligibility_problems
    @eligibility_problems ||= GeminiHandwritingTranscriptionService.new(work: work).work_eligibility_problems
  end

  def transcription_request
    work.handwriting_transcription_request
  end

  def request_status_message
    transcription_request&.status_message
  end

  # Once a request has been made, its status says what happened, so we only warn beforehand.
  def eligibility_warning
    return nil if transcription_request.present? || eligibility_problems.empty?

    "We don't recommend requesting a handwriting transcription for this work, because " \
      "#{eligibility_problems.to_sentence}. A request would be recorded as failed, " \
      "without being sent to Gemini."
  end

  def hint
    return nil unless show_handwriting_info?

    messages = [request_status_message, eligibility_warning].compact
    safe_join(messages, tag.br) if messages.present?
  end
end
