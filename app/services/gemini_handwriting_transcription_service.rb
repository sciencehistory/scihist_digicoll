require 'http'

# GeminiHandwritingTranscriptionService.new(work: work).add_transcription!
#
# will ask Gemini for a transcript for each image asset on the work, then
# attach a transcript to the :handwriting_transcription attribute for each image asset in the work.
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

  # Asks Gemini to transcribe the work's images, and attaches the transcripts to them.
  def add_transcription!
    if work_eligibility_problems.present?
      raise IneligibleWorkError,
        "We will not send Work #{work.friendlier_id} to be transcribed, because #{work_eligibility_problems.to_sentence}."
    end

    update_handwriting_transcription_request(status: 'started')

    Dir.mktmpdir do |dir|
      staged_images = stage_images(dir)

      response = request_transcription(staged_images)
      update_handwriting_transcription_request(status: 'received')

      process_results(response: response, staged_images: staged_images)
    end
    update_handwriting_transcription_request(status: 'success')
  end

  # Removes the handwriting transcriptions from all of the work's assets, forgets
  # the state of the request that created them, and reindexes the work.
  #
  # A rare operation, so we keep it simple: reindex once at the end, instead of
  # once per asset.
  def remove_transcription!
    Kithe::Indexable.index_with(disable_callbacks: true) do
      work.members.each do |member|
        next unless member.is_a?(Asset) && member.handwriting_transcription.present?

        member.update!(handwriting_transcription: nil)
      end

      work.handwriting_transcription_request = nil
      work.save!
    end

    ReindexWorksJob.perform_later([work.id])
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

    update_handwriting_transcription_request(status: 'requested', start_time: Time.current)

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
    update_handwriting_transcription_request(status: 'failure', error: msg)

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
    update_handwriting_transcription_request(status: 'failure', error: msg)
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
      update_handwriting_transcription_request(status: 'failure', error: msg)
      raise InvalidResponseError, msg
    end

    text
  rescue JSON::ParserError => e
    msg = "Gemini's response was not valid JSON. JSON error: #{e.message}"
    update_handwriting_transcription_request(status: 'failure', error: msg)
    raise InvalidResponseError, msg
  end

  # Parse the JSON transcript text returned by Gemini
  def parse_response!(stdout)
    JSON.parse(stdout)
  rescue JSON::ParserError => e
    msg = "Gemini's response was not valid JSON. JSON error: #{e.message}"

    update_handwriting_transcription_request(status: 'failure', error: msg)
    raise InvalidResponseError, msg
  end

  # Checks the transcript info looks the way it should. Returns a hash of pages.
  def extract_and_validate_pages!(data, staged_images:)
    pages = data["pages"]

    unless pages.is_a?(Array)
      msg = "Gemini response does not contain a pages array"
      update_handwriting_transcription_request(status: 'failure', error: msg)
      raise InvalidResponseError, msg
    end

    pages.each do |page|
      unless page.is_a?(Hash) &&
          page["filename"].present? &&
          page["transcript"].is_a?(String)

        msg = "Gemini returned an invalid page entry: #{page.inspect}"
        update_handwriting_transcription_request(status: 'failure', error: msg)
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
      update_handwriting_transcription_request(status: 'failure', error: msg)
      raise InvalidResponseError, msg
    end

    pages
  end

  # Attach the transcript of each page to its asset. Saving an asset with a new
  # handwriting_transcription re-indexes its parent work, so we batch to send
  # all those updates to Solr together.
  def attach_transcripts!(pages, staged_images:)
    pages_by_filename =
      pages.index_by { |page| page.fetch("filename") }

    Kithe::Indexable.index_with(batching: true) do
      Asset.transaction do
        staged_images.each do |image|
          asset = image.fetch(:asset)
          filename = image.fetch(:filename)
          transcript = pages_by_filename.fetch(filename).fetch("transcript")

          Rails.logger.info(
            "Attaching Gemini HTR transcript to #{asset.friendlier_id}"
          )
          asset.update!(handwriting_transcription: transcript)
        end
      end
    end
  end

  # Published IMAGE assets with a derivative we consider high-res enough to use.
  def eligible_assets
    @eligible_assets ||= work.
      members.
      includes(:leaf_representative).
      where(published: true, type: Asset.sti_name).
      order(:position).
      select do |asset|
        representative = asset.leaf_representative
        next false unless representative&.content_type&.start_with?("image/")
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

  # Keep track of the state of the transcription request.
  # Takes any attributes of Work::HandwritingTranscriptionRequest (status:, error:, start_time:, ...).
  def update_handwriting_transcription_request(**attributes)
    (work.handwriting_transcription_request ||= Work::HandwritingTranscriptionRequest.new).assign_attributes(attributes)
    # this metadata isn't indexed, so no need to talk to Solr here
    Kithe::Indexable.index_with(disable_callbacks: true) { work.save! }
  end
end
