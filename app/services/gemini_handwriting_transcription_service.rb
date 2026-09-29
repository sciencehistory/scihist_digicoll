require 'http'

# A class to wrap our requests to Google Gemini to transcribe a work.
#
# GeminiHandwritingTranscriptionService.new(work: work).call
#
# will ask Gemini for a transcript for each image asset on the work, then
# attach a transcript to the :htr_transcript attribute for the asset.
#
# We consider the transcript ephemeral, machine-produced metadata,
# so we store it in derived_metadata_jsonb.
class GeminiHandwritingTranscriptionService

  # this is just the superclass of all the errors this class can throw.
  class Error < StandardError; end

  class AdapterError < Error; end
  class InvalidResponseError < Error; end
  class UnsupportedImageTypeError < Error; end
  class IneligibleWorkError < Error; end

  MAX_FILES_TO_TRANSCRIBE = 10

  GEMINI_API_BASE_URL = "https://generativelanguage.googleapis.com/v1beta"

  # How long we'll wait on Gemini before giving up -- a multi-page, multi-image
  # request can legitimately take a couple of minutes.
  GEMINI_HTTP_TIMEOUT = 300 # seconds

  def initialize(work:)
    @work = work
  end

  # Main method to invoke this class.
  def call
    if work_eligibility_problems.present?
      raise IneligibleWorkError,
        "We will not send Work #{work.friendlier_id} to be transcribed, because #{work_eligibility_problems.to_sentence}."
    end

    db_log_write!(status: 'started')

    Dir.mktmpdir do |dir|
      staged_images = stage_images(dir)

      response = request_transcription(staged_images)
      db_log_write!(status: 'received')

      process_results(response: response, staged_images: staged_images)
    end
    db_log_write!(status: 'success')
  end

  # Any and all reasons to exclude a work from receiving a transcript.
  def work_eligibility_problems
    problems = []
    if eligible_assets.empty?
      problems << "no usable images were found"
    end
    if eligible_assets.count > MAX_FILES_TO_TRANSCRIBE
      problems  << "we are limiting the number of requested pages to transcribe to #{MAX_FILES_TO_TRANSCRIBE}"
    end
    problems
  end

  private

  attr_reader :work

  # Downloads the assets to a temporary directory, from which they will be sent to Gemini.
  # It's possible to imagine sending derivative URLS directly to Gemini,
  # but this is simpler and probably more practical.
  def stage_images(dir)
    eligible_assets.each_with_index.map do |asset, index|
      representative = asset.leaf_representative

      image_derivative =
        representative.file_derivatives[:download_large] ||
        representative.file_derivatives[:download_full]

      filename = [
        format("%04d", index + 1),
        asset.friendlier_id
      ].join("-") + extension_for(image_derivative)

      path = File.join(dir, filename)

      File.open(path, "wb") do |out|
        IO.copy_stream(image_derivative.to_io, out)
      end

      {
        asset: asset,
        filename: filename,
        path: path,
        mime_type: image_derivative.mime_type
      }
    end
  end

  def gemini_client
    @gemini_client ||= HTTP
      .headers("x-goog-api-key" => ScihistDigicoll::Env.lookup("gemini_api_key"))
      .timeout(GEMINI_HTTP_TIMEOUT)
  end


  # Posts the request directly to Gemini's REST API. Returns the raw HTTP::Response;
  # #process_results is responsible for validating it and pulling out the transcript.
  def request_transcription(staged_images)
    Rails.logger.info(
      "Sending work #{work.friendlier_id} to Gemini for handwriting transcription"
    )

    db_log_write!(status: 'requested',  start_time: Time.current)

    model = ScihistDigicoll::Env.lookup("gemini_model")

    gemini_client.post(
      "#{GEMINI_API_BASE_URL}/models/#{model}:generateContent",
      json: GeminiContentRequestBuilder.new(
        staged_images: staged_images,
        work_description: work.description
      ).call
    )
  rescue HTTP::Error, SocketError => e
    msg = "Could not reach Gemini: #{e.class}: #{e.message}"
    db_log_write!(error_message: msg)

    raise AdapterError, msg
  end

  # The transcript, and notes about the transcription process,
  # should come in via the response body. This method attaches each page's
  # transcript to the corresponding asset.
  def process_results(response:, staged_images:)
    validate_adapter_result!(response)

    text = extract_generated_text!(response)

    Rails.logger.debug("Gemini raw response for work #{work.friendlier_id}: #{text}")

    data = parse_response!(text)

    pages =
      extract_and_validate_pages!(
        data,
        staged_images: staged_images
      )

    attach_transcripts!(
      pages,
      staged_images: staged_images
    )

    Rails.logger.info(
      "Gemini handwriting transcription completed for work #{work.friendlier_id}"
    )
  end

  # Alert the Rails log of any problems coming back from the Gemini API itself
  # (as opposed to problems with the content of its response, handled below).
  def validate_adapter_result!(response)
    return if response.status.success?

    msg = "Gemini transcription failed with HTTP status #{response.status}: #{error_summary(response)}"
    db_log_write!(error_message: msg)
    raise AdapterError, msg
  end

  def error_summary(response)
    JSON.parse(response.body.to_s).dig("error", "message")
  rescue JSON::ParserError
    response.body.to_s.truncate(500)
  end

  # Pulls the model's generated text out of Gemini's response envelope.
  def extract_generated_text!(response)
    envelope = JSON.parse(response.body.to_s)
    text = envelope.dig("candidates", 0, "content", "parts", 0, "text")

    if text.blank?
      msg = "Gemini returned an empty response"
      db_log_write!(error_message: msg)
      raise InvalidResponseError, msg
    end

    text
  rescue JSON::ParserError => e
    msg = "Gemini's response was not valid JSON. JSON error: #{e.message}"
    db_log_write!(error_message: msg)
    raise InvalidResponseError, msg
  end

  # Parse the JSON transcript text returned by Gemini
  def parse_response!(stdout)
    JSON.parse(stdout)
  rescue JSON::ParserError => e
    msg = "Gemini's response was not valid JSON. JSON error: #{e.message}"

    db_log_write!(error_message: msg)
    raise InvalidResponseError, msg
  end

  # Checks the transcript info looks the way it should. Returns a hash of pages.
  def extract_and_validate_pages!(data, staged_images:)
    pages = data["pages"]

    unless pages.is_a?(Array)
      msg = "Gemini response does not contain a pages array"
      db_log_write!(error_message: msg)
      raise InvalidResponseError, msg
    end

    pages.each do |page|
      unless page.is_a?(Hash) &&
          page["filename"].present? &&
          page["transcript"].is_a?(String)

        msg = "Gemini returned an invalid page entry: #{page.inspect}"
        db_log_write!(error_message: msg)
        raise InvalidResponseError, msg
      end
    end

    expected_filenames =
      staged_images.map { |image| image.fetch(:filename) }

    returned_filenames =
      pages.map { |page| page.fetch("filename") }

    unless returned_filenames.sort == expected_filenames.sort
      msg = <<~MESSAGE.squish
        Gemini returned an unexpected set of filenames.
        Expected: #{expected_filenames.inspect}.
        Returned: #{returned_filenames.inspect}.
      MESSAGE
      db_log_write!(error_message: msg)
      raise InvalidResponseError, msg
    end

    pages
  end

  # Attach the transcript of each page to its asset
  def attach_transcripts!(pages, staged_images:)
    pages_by_filename =
      pages.index_by { |page| page.fetch("filename") }

    Asset.transaction do
      staged_images.each do |image|
        asset = image.fetch(:asset)
        filename = image.fetch(:filename)
        transcript = pages_by_filename.fetch(filename).fetch("transcript")

        Rails.logger.info(
          "Attaching Gemini HTR transcript to #{asset.friendlier_id}"
        )
        asset.update!(htr_transcript: transcript)
      end
    end
  end

  # Published assets with derivatives we can use.
  def eligible_assets
    @eligible_assets ||= work.
      members.
      includes(:leaf_representative).
      where(published: true, type: Asset.sti_name).
      order(:position).
      select do |asset|
        representative = asset.leaf_representative
        return false unless representative&.content_type&.start_with?("image/")
        representative.file_derivatives[:download_large].present? ||
          representative.file_derivatives[:download_full].present?
      end
  end

  def extension_for(image_derivative)
    Rack::Mime::MIME_TYPES.key(image_derivative.mime_type) ||
      raise(
        UnsupportedImageTypeError,
        "Unknown MIME type: #{image_derivative.mime_type}"
      )
  end

  # We use these methods to keep track of the state of the transcription request.
  def db_log_write!(status: status, error_message: nil, start_time: nil)

    db_log['errors'] << error_message if error_message.present?

    fields = if error_message.nil?
      { status: status }
    else
      { status: 'error' }
    end

    fields['start_time'] = start_time if start_time.present?

    work.htr_transcript_status = db_log.merge!(fields)
    work.save!
  end

  def db_log
    @db_log ||= { 'errors' => [], 'status' => "", 'start_time' => nil }
  end
end
