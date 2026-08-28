class GeminiHandwritingTranscriptionService

  class Error < StandardError; end
  class AdapterError < Error; end
  class InvalidResponseError < Error; end
  class NoEligibleAssetsError < Error; end
  class UnsupportedImageTypeError < Error; end

  def initialize(work:)
    @work = work
  end

  def call
    byebug
    if eligible_assets.empty?
      raise NoEligibleAssetsError,
        "No eligible image assets were found for work #{work.friendlier_id}"
    end

    Dir.mktmpdir do |dir|
      staged_images = stage_images(dir)
      manifest = generate_manifest(staged_images)


      stdout, stderr, status = request_transcription(manifest)

      process_results(
        stdout: stdout,
        stderr: stderr,
        status: status,
        staged_images: staged_images
      )
    end
  end

  private

  attr_reader :work

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

    Open3.capture3(
      {
        "GEMINI_API_KEY" => gemini_api_key
      },
      python_command,
      stdin_data: manifest,
      chdir: Rails.root.to_s
    )
  end

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

  def log_adapter_stderr(stderr)
    return if stderr.blank?

    Rails.logger.warn(
      "Gemini HTR Python adapter stderr:\n#{stderr}"
    )
  end

  def validate_adapter_result!(stdout:, status:)
    unless status.success?
      raise AdapterError,
        "Gemini transcription failed with exit status #{status.exitstatus}"
    end

    if stdout.blank?
      raise InvalidResponseError,
        "Gemini returned an empty response"
    end
  end

  def preserve_raw_response(stdout)
    output_directory = debug_output_directory
    return unless output_directory

    FileUtils.mkdir_p(output_directory)

    path = output_directory.join("raw_response.json")
    File.write(path, stdout)

    path
  end

  def parse_response!(stdout, raw_response_path:)
    JSON.parse(stdout)
  rescue JSON::ParserError => e
    message = +"Gemini's response was not valid JSON."

    if raw_response_path
      message << " Raw response preserved at #{raw_response_path}."
    end

    message << " JSON error: #{e.message}"

    raise InvalidResponseError, message
  end

def debug_output_directory
  return unless Rails.env.development?

  @debug_output_directory ||= Rails.root.join(
    "tmp",
    "gemini_htr",
    work.friendlier_id,
    "#{Time.current.strftime('%Y%m%d-%H%M%S')}-#{SecureRandom.hex(4)}"
  )
end


  def extract_and_validate_pages!(data, staged_images:)
    pages = data["pages"]

    unless pages.is_a?(Array)
      raise InvalidResponseError,
        "Gemini response does not contain a pages array"
    end

    pages.each do |page|
      unless page.is_a?(Hash) &&
          page["filename"].present? &&
          page["transcript"].is_a?(String)
        raise InvalidResponseError,
          "Gemini returned an invalid page entry: #{page.inspect}"
      end
    end

    expected_filenames =
      staged_images.map { |image| image.fetch(:filename) }

    returned_filenames =
      pages.map { |page| page.fetch("filename") }

    unless returned_filenames.sort == expected_filenames.sort
      raise InvalidResponseError, <<~MESSAGE.squish
        Gemini returned an unexpected set of filenames.
        Expected: #{expected_filenames.inspect}.
        Returned: #{returned_filenames.inspect}.
      MESSAGE
    end

    pages
  end

  def attach_transcripts!(pages, staged_images:)
    pages_by_filename =
      pages.index_by { |page| page.fetch("filename") }

    Asset.transaction do
      staged_images.each do |image|
        asset = image.fetch(:asset)
        filename = image.fetch(:filename)

        transcript =
          pages_by_filename.fetch(filename).fetch("transcript")

        Rails.logger.info(
          "Attaching Gemini HTR transcript to #{asset.friendlier_id}"
        )

        asset.update!(transcription: transcript)
      end
    end
  end

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

end