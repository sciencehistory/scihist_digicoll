class GeminiHandwritingTranscriptionService

  class Error < StandardError; end
  class AdapterError < Error; end
  class InvalidResponseError < Error; end
  class UnsupportedImageTypeError < Error; end
  class IneligibleWorkError < Error; end

  MAX_FILES_TO_TRANSCRIBE = 10

  # Where we store the transcripts on the asset:
  HTR_TRANSCRIPT_ASSET_ATTRIBUTE = :htr_transcript

  # Where we store the state of attempts to get transcripts on the work:
  HTR_TRANSCRIPT_ATTEMPT_WORK_ATTRIBUTE = :gemini_htr_transcript_requests

  # A class to wrap our requests to Google Gemini to transcribe a work.
  # GeminiHandwritingTranscriptionService.new(work: work).call
  # will ask Gemini for a transcript for each image asset on the work, then 
  # attach a transcript to the :htr_transcript attribute for the asset.
  # This is stored as as ephemeral JSON metadata in derived_metadata_jsonb.

  def initialize(work:)
    @work = work
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
    unless work.published?
      problems  << "this work is not published"
    end
    unless public_domain?
      problems  << "this work is not in the public domain"
    end
    problems
  end

  # Main method to invoke this class.
  def call
    if work_eligibility_problems.present?
      raise IneligibleWorkError,
        "We will not send Work #{work.friendlier_id} to be transcribed, because #{work_eligibility_problems.to_sentence}."
    end

    db_log_status('started')

    Dir.mktmpdir do |dir|
      staged_images = stage_images(dir)
      manifest = generate_manifest(staged_images)


      stdout, stderr, status = request_transcription(manifest)
      db_log_status('received')

      process_results(
        stdout: stdout,
        stderr: stderr,
        status: status,
        staged_images: staged_images
      )
    end
    db_log_status('success')

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
        path: path
      }
    end
  end

  # Calls the thin Python wrapper with info about our request.
  def request_transcription(manifest)
    gemini_api_key =
      ScihistDigicoll::Env.lookup("gemini_api_key")

    python_command =
      ScihistDigicoll::Util.prefix_python_exec_command(
        "./python_script/gemini_htr.py"
      )

    Rails.logger.info(
      "Sending work #{work.friendlier_id} to Gemini for handwriting transcription"
    )

    db_log_status('requested')
    Open3.capture3(
      {
        "GEMINI_API_KEY" => gemini_api_key
      },
      *python_command,
      stdin_data: manifest,
      chdir: Rails.root.to_s
    )
  end

  # The transcript, and notes about the transcription process,
  # should come in via stdout. This method attaches each page's transcript
  # to the corresponding asset.
  def process_results(stdout:, stderr:, status:, staged_images:)
    log_adapter_stderr(stderr)
    validate_adapter_result!(stdout:, status:)

    raw_response_path = preserve_raw_response(stdout)
    data = parse_response!(stdout, raw_response_path:)

    pages =
      extract_and_validate_pages!(
        data,
        staged_images: staged_images
      )

    log_model_feedback(data)
    write_transcript_files(pages)

    attach_transcripts!(
      pages,
      staged_images: staged_images
    )

    Rails.logger.info(
      "Gemini handwriting transcription completed for work #{work.friendlier_id}"
    )
  end

  # Sends any errors coming from Gemini to the Rails log.
  def log_adapter_stderr(stderr)
    return if stderr.blank?

    Rails.logger.warn(
      "Gemini HTR Python adapter stderr:\n#{stderr}"
    )
  end

  # Alert the Rails log of any problems coming in from the python adapter.
  def validate_adapter_result!(stdout:, status:)
    unless status.success?
      msg = "Gemini transcription failed with exit status #{status.exitstatus}"
      db_log_error(msg)
      raise AdapterError, msg
    end

    if stdout.blank?
      msg = "Gemini returned an empty response"
      db_log_error(msg)
      raise InvalidResponseError, msg
    end
  end

  # In development, save the files in a temp directory so we can debug problems.
  def preserve_raw_response(stdout)
    output_directory = debug_output_directory
    return unless output_directory

    FileUtils.mkdir_p(output_directory)

    path = output_directory.join("raw_response.json")
    File.write(path, stdout)

    path
  end

  # Parse the JSON returned from the Python wrapper
  def parse_response!(stdout, raw_response_path:)
    JSON.parse(stdout)
  rescue JSON::ParserError => e
    msg = +"Gemini's response was not valid JSON."

    if raw_response_path
      msg << " Raw response preserved at #{raw_response_path}."
    end

    msg << " JSON error: #{e.message}"

    db_log_error(msg)
    raise InvalidResponseError, msg

  end

  # Only used in dev
  def debug_output_directory
    return unless Rails.env.development?

    @debug_output_directory ||= Rails.root.join(
      "tmp",
      "gemini_htr",
      work.friendlier_id,
      transcript_request_id
    )
  end

  def transcript_request_id
    @transcript_request_id  ||= "#{Time.current.strftime('%Y%m%d-%H%M%S')}-#{SecureRandom.hex(4)}"
  end


  # Checks the transcript info looks the way it should. Returns a hash of pages.
  def extract_and_validate_pages!(data, staged_images:)
    pages = data["pages"]

    unless pages.is_a?(Array)
      msg = "Gemini response does not contain a pages array"
      db_log_error(msg)
      raise InvalidResponseError, msg
    end

    pages.each do |page|
      unless page.is_a?(Hash) &&
          page["filename"].present? &&
          page["transcript"].is_a?(String)

        msg = "Gemini returned an invalid page entry: #{page.inspect}"
        db_log_error(msg)
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
      db_log_error(msg)
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

        attach_transcript!(
          asset,
          pages_by_filename.fetch(filename).fetch("transcript")
        )
      end
    end
  end

  def attach_transcript!(asset, transcript)
    Rails.logger.info(
      "Attaching Gemini HTR transcript to #{asset.friendlier_id}"
    )
    asset.update!(HTR_TRANSCRIPT_ASSET_ATTRIBUTE => transcript)
  end

  # The model will often provide notes about the transcription process.
  # Put these notes in the rails log so we can look at them in production, as needed.
  def log_model_feedback(data)
    if data["general_feedback"].present?
      Rails.logger.info(
        "Gemini HTR general feedback for work #{work.friendlier_id}: " \
        "#{data['general_feedback']}"
      )
    end

    data["pages"].each do |page|
      next if page["page_notes"].blank?

      Rails.logger.info(
        "Gemini HTR notes for #{page['filename']}: " \
        "#{page['page_notes']}"
      )
    end
  end

  # Only in dev, write the transcript pages out to disk.
  def write_transcript_files(pages)
    output_directory = debug_output_directory
    return unless output_directory

    FileUtils.mkdir_p(output_directory)

    pages.each do |page|
      filename = page.fetch("filename")
      transcript = page.fetch("transcript")

      base_name =
        File.basename(filename, File.extname(filename))

      transcript_path =
        output_directory.join("#{base_name}.txt")

      File.write(transcript_path, transcript)

      Rails.logger.debug(
        "Saved Gemini HTR transcript to #{transcript_path}"
      )
    end
  end


  # Returns the prompt we send to Gemini in JSON form.
  def generate_manifest(staged_images)
    system_instruction = <<~PROMPT
      You are an expert paleographer and archival OCR engine.
      You are analyzing a sequence of handwritten pages written by the same person.
      You are provided with some context about the images, as follows: "#{work.description}."

      TASK INSTRUCTIONS:
      1. Cross-Page Learning: Examine the handwriting, vocabulary, and shorthand across ALL provided images first to establish a baseline for the script. Use context from the entire set to clarify ambiguous words on individual pages.
      2. Transcription Rules:
         - Preserve exact historical/personal spelling ("warts and all"). Do NOT auto-correct.
         - Hew strictly to original wording.
         - If you are less than ~90% confident about a specific word, you may place a [?] after the word to indicate doubt.
         - Omit diagrams, formulas, sketches, and annotations directly tied to diagrams. Focus strictly on main running blocks of text.
      3. Output Format:
         - Output a transcript for EACH page.
      4. Response Format:
         - Return a JSON object containing the transcript for each filename.
      5. Feedback & Reporting:
         - Use 'general_feedback' to note any systemic issues (e.g., if you suspect the output might cut off, or general handwriting observations).
         - Use 'page_notes' on individual pages to explain why specific sections were omitted, note illegible words, or point out ignored diagrams/annotations.
    PROMPT

    response_schema = {
      type: "OBJECT",
      properties: {
        general_feedback: {
          type: "STRING",
          description: "Optional overall comments about the batch, handwriting legibility, token limits, or context."
        },
        pages: {
          type: "ARRAY",
          items: {
            type: "OBJECT",
            properties: {
              filename: {
                type: "STRING"
              },
              transcript: {
                type: "STRING"
              },
              page_notes: {
                type: "STRING",
                description: "Optional notes on this specific page (e.g. unreadable words, omitted diagrams, or specific ambiguities)."
              }
            },
            required: [
              "filename",
              "transcript"
            ]
          }
        }
      },
      required: ["pages"]
    }

    #
    # Construct the ordered multimodal prompt.
    #
    # Keeping the filename immediately before its corresponding image
    # gives Gemini an explicit association between the two.
    #
    contents = []

    staged_images.each do |image|
      contents << {
        type: "text",
        text: "Image File: #{image.fetch(:filename)}"
      }

      contents << {
        type: "image",
        path: image.fetch(:path)
      }
    end

    contents << {
      type: "text",
      text: <<~TEXT.strip
        Please analyze all pages above, learn the handwriting style,
        and produce the requested transcript strings in JSON format.
      TEXT
    }

    manifest = {
      model: ScihistDigicoll::Env.lookup("gemini_model"),
      system_instruction: system_instruction,
      response_schema: response_schema,
      contents: contents,
      generation_config: {
        max_output_tokens: 65_536,
        media_resolution: "MEDIA_RESOLUTION_HIGH"
      }
    }

    JSON.generate(manifest)
  end


  # Returns true if we consider this work in "the public domain".
  # Simplest rule that could work for now; subject to input from curators.
  def public_domain?
    ['http://creativecommons.org/publicdomain/mark/1.0/'].include? work.rights
  end

  # Published assets with derivatives we can use.
  def eligible_assets
    @eligible_assets ||= work.
      members.
      includes(:leaf_representative).
      where(published: true, type: Asset.sti_name).
      order(:position).
      select { |asset| eligible_asset?(asset) }
  end

  def eligible_asset?(asset)
    representative = asset.leaf_representative
    return false unless representative&.content_type&.start_with?("image/")

    derivatives = representative.file_derivatives

    derivatives[:download_large].present? ||
      derivatives[:download_full].present?
  end

  def extension_for(image_derivative)
    Rack::Mime::MIME_TYPES.key(image_derivative.mime_type) ||
      raise(
        UnsupportedImageTypeError,
        "Unknown MIME type: #{image_derivative.mime_type}"
      )
  end

  def db_log_status(status)
    db_log['status'] = status
    db_log_save!
  end

  def db_log_error(error)
    db_log_status('error')
    db_log['error'] = error
    db_log_save!
  end

  # Store state of the request on the work
  def db_log_save!
    set_work_transcript_requests( {} ) if work_transcript_requests.nil?
    work_transcript_requests[transcript_request_id] = db_log
    work.save!
  end

  def work_transcript_requests
    work.public_send(HTR_TRANSCRIPT_ATTEMPT_WORK_ATTRIBUTE)
  end

  def set_work_transcript_requests(val)
    work.public_send("#{HTR_TRANSCRIPT_ATTEMPT_WORK_ATTRIBUTE}=", val)
  end

  def db_log
    @db_log ||= { 'errors' => [], 'status' => "" }
  end
end