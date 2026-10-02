class GeminiHandwritingTranscriptionComponent < ApplicationComponent
  attr_reader :work

  def initialize(work)
    @work = work
  end

  def eligibility_problems
    GeminiHandwritingTranscriptionService.new(work: work).work_eligibility_problems
  end

  # The Work::HtrTranscriptionRequest currently stored on the work, or nil if
  # none has ever been made. (We only ever keep the current request, not a
  # history of past attempts.)
  def current_request
    work.htr_transcription_request
  end

  # A human-readable sentence describing the status of the current
  # transcription request, or nil if there has never been one.
  def current_request_status_message
    request = current_request
    return nil unless request

    time = formatted_start_time(request)

    if request.success?
      if time
        "An automatic transcript exists; it was created on #{time} #{transcript_link}.".html_safe
      else
        "An automatic transcript exists #{transcript_link}.".html_safe
      end
    elsif request.failure?
      requested = time ? "We requested a transcript from Google at #{time}" : "We requested a transcript from Google"

      if request.error.present?
        "#{requested}, but it failed. The error was: #{request.error}"
      else
        "#{requested}, but it failed; more information is available in the logs."
      end
    else
      if time
        "We requested a transcript from Google at #{time}. It's not ready yet."
      else
        "We requested a transcript from Google. It's not ready yet."
      end
    end
  end

  # Label for the "request transcription" button -- worded differently if a
  # successful transcript already exists, since a new request would replace it.
  def request_button_label
    if current_request&.success?
      "Request a new transcription to replace the current one"
    else
      "Request transcription"
    end
  end

  # True if the current request hasn't reached a final status yet -- we don't
  # want to let the admin fire off a second, concurrent request while one is
  # still in progress.
  def request_pending?
    current_request&.pending? || false
  end

  # TEMPORARY, for debugging -- raw contents of the transcript request log
  # we keep on the work, as pretty-printed JSON.
  def transcript_request_json
    JSON.pretty_generate(current_request.as_json || {})
  end

  private

  # Link to the htr-transcript tab of the work's public-facing view.
  def transcript_link
    link_to("(view transcript)", work_path(work, anchor: "tab=htr-transcript"))
  end

  def formatted_start_time(request)
    return nil if request.start_time.blank?

    l(request.start_time, format: :admin_compact)
  end
end
