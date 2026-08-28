class GeminiHandwritingTranscriptionService
  class MissingDerivativeError < StandardError
    attr_reader :asset

    def initialize(asset)
      @asset = asset

      super(
        "Unable to find a suitable file to transcribe " \
        "for asset #{asset.friendlier_id}."
      )
    end
  end

  def initialize(work:, assets:)
    @work = work
    @assets = assets
  end

  def call
    Dir.mktmpdir do |dir|
      image_paths = stage_images(dir)
      manifest = generate_manifest(image_paths)

      stdout, stderr, status = request_transcription(manifest)

      process_results(
        stdout: stdout,
        stderr: stderr,
        status: status
      )
    end
  end

  private

  attr_reader :work, :assets

  def stage_images(dir)
    assets.each_with_index.map do |asset, index|
      filename =
        "#{format('%04d', index + 1)}-#{asset.friendlier_id}.jpg"

      path = File.join(dir, filename)

      derivative =
        asset.file_derivatives[:download_large] ||
        asset.file_derivatives[:download_full]

      raise MissingDerivativeError, asset if derivative.nil?

      File.open(path, "wb") do |out|
        IO.copy_stream(derivative.to_io, out)
      end

      path
    end
  end

  def request_transcription(manifest)
    gemini_api_key =
      ScihistDigicoll::Env.lookup("gemini_api_key")

    python_command =
      ScihistDigicoll::Util.prefix_python_exec_command(
        "./python_script/gemini_htr.py"
      )

    puts "Sending request to Gemini..."

    Open3.capture3(
      {
        "GEMINI_API_KEY" => gemini_api_key
      },
      python_command,
      stdin_data: manifest,
      chdir: Rails.root.to_s
    )
  end

  def process_results(stdout:, stderr:, status:)
    #
    # The Python adapter reserves stdout for the model response.
    # Any diagnostic output goes to stderr.
    #
    warn stderr if stderr.present?

    unless status.success?
      abort "Gemini transcription failed with exit status #{status.exitstatus}"
    end

    if stdout.blank?
      abort "Gemini returned an empty response."
    end

    output_dir_name = "gemini_results_#{work.friendlier_id}"
    file_path = File.join(output_dir_name, "raw_response.json")

    FileUtils.mkdir_p(output_dir_name)
    File.write(file_path, stdout)

    begin
      data = JSON.parse(stdout)
    rescue JSON::ParserError => e
      abort <<~MESSAGE
        Gemini's response was not valid JSON.

        # The raw response has been preserved at:
        #   #{raw_response_path}

        JSON error:
          #{e.message}
      MESSAGE
    end

    if data["general_feedback"].present?
      puts
      puts "=== MODEL GENERAL FEEDBACK ==="
      puts data["general_feedback"]
      puts "=============================="
      puts
    end

    data.fetch("pages", []).each do |page|
      filename = page.fetch("filename")
      transcript = page.fetch("transcript")
      notes = page["page_notes"]

      base_name =
        File.basename(filename, File.extname(filename))

      transcript_path =
        File.join(output_dir_name, "#{base_name}.txt")

      File.write(transcript_path, stdout)

      puts "Saved #{transcript_path}"

      if notes.present?
        puts
        puts "=== PAGE NOTES: #{filename} ==="
        puts notes
        puts "============================="
        puts
      end
    end

    unless assets.count == data.fetch("pages", []).count
      abort "Wrong number of transcripts."
    end

    pages = data.fetch("pages", [])

    transcript_map =
      assets.map do |asset|
        [
          asset.friendlier_id,
          pages.find do |page|
            page["filename"].include?(asset.friendlier_id)
          end
        ]
      end.to_h

    # do an asset transaction here
    assets.each do |asset|
      friendlier_id = asset.friendlier_id
      transcript = transcript_map[friendlier_id]["transcript"]

      puts "Attaching transcript to #{friendlier_id}."

      asset.update!(transcription: transcript)
    end

    puts "Processing complete!"
  end

  def generate_manifest(image_paths)
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

    image_paths.each do |path|
      contents << {
        type: "text",
        text: "Image File: #{File.basename(path)}"
      }

      contents << {
        type: "image",
        path: path.to_s
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
end