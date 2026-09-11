class GeminiHandwritingTranscriptionComponent < ApplicationComponent
  attr_reader :work

  def initialize(work)
    @work = work
  end

  def eligibility_problems
    GeminiHandwritingTranscriptionService.new(work: work).work_eligibility_problems
  end

  # The single most recent transcription attempt logged on the work, or nil
  # if none have ever been made.
  def most_recent_request
    requests = work.public_send(Work::HTR_TRANSCRIPT_REQUEST_ATTRIBUTE) || {}
    requests.values.max_by { |request| request["start_time"] || "" }
  end

  # A human-readable sentence describing the status of the most recent
  # transcription attempt, or nil if there has never been one.
  def most_recent_request_status_message
    request = most_recent_request
    return nil unless request

    time = formatted_start_time(request)

    case request["status"]
    when "success"
      if time
        "An automatic transcript exists; it was created on #{time} #{transcript_link}.".html_safe
      else
        "An automatic transcript exists #{transcript_link}.".html_safe
      end
    when "error"
      if time
        "We requested a transcript from Google at #{time}, but it failed; more information is available in the logs."
      else
        "We requested a transcript from Google, but it failed; more information is available in the logs."
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
    if most_recent_request&.dig("status") == "success"
      "Request a new transcription to replace the current one"
    else
      "Request transcription"
    end
  end

  # Statuses GeminiHandwritingTranscriptionService considers final -- once a
  # request reaches one of these, it's done and won't change on its own.
  TERMINAL_STATUSES = ["success", "error"].freeze

  # True if the most recent request hasn't reached a final status yet (e.g.
  # "started", "requested", "received") -- we don't want to let the admin
  # fire off a second, concurrent request while one is still in progress.
  def request_pending?
    status = most_recent_request&.dig("status")
    status.present? && !TERMINAL_STATUSES.include?(status)
  end

  # TEMPORARY, for debugging -- raw contents of the transcript request log
  # we keep on the work, as pretty-printed JSON.
  def raw_transcript_requests_json
    JSON.pretty_generate(work.public_send(Work::HTR_TRANSCRIPT_REQUEST_ATTRIBUTE) || {})
  end

  private

  # Link to the htr-transcript tab of the work's public-facing view.
  def transcript_link
    link_to("(view transcript)", work_path(work, anchor: "tab=htr-transcript"))
  end

  def formatted_start_time(request)
    start_time = request["start_time"]
    return nil if start_time.blank?

    l(Time.zone.parse(start_time), format: :admin_compact)
  end
end
