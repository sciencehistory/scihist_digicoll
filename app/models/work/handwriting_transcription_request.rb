class Work
  # The state of the current (or most recent) request to transcribe a work's
  # handwriting. Stored in the work's derived_metadata_jsonb, as :handwriting_transcription_request.
  # We only keep the current request, not a history of past ones.
  #
  # Statuses move from "started" -> "requested" -> "received", and end in one of
  # the terminal statuses, "success" or "failure". On failure, `error` holds the message.
  #
  # Unknown keys are allowed, so we can add more details about requests later
  # without having to change this class.
  class HandwritingTranscriptionRequest
    include AttrJson::Model

    attr_json_config(unknown_key: :allow)

    STATUS_VALUES = %w{started requested received success failure}

    attr_json :status, :string
    validates :status, inclusion: { in: STATUS_VALUES, allow_blank: true }

    attr_json :error, :string
    attr_json :start_time, :datetime

    def success?
      status == "success"
    end

    def failure?
      status == "failure"
    end

    # Has reached a final status; it won't change on its own any more.
    def finished?
      success? || failure?
    end

    # Underway, but not finished yet.
    def pending?
      status.present? && !finished?
    end
  end
end
