namespace :scihist do
  desc """
    Downloads images and a description so they can be sent to Gemini
    so that it can prepare HOCR for them.

    Example:

    WORK_FRIENDLIER_ID='8npkswk' \
    IMAGES_LOCAL_DIR='/where/to/put/images' \
    bundle exec rake scihist:prepare_hocr_request
  """
  task :prepare_transcript_request => :environment do
    images_local_dir = ENV['IMAGES_LOCAL_DIR']
    work_friendlier_id = ENV['WORK_FRIENDLIER_ID']


    unless images_local_dir.present? && work_friendlier_id.present?
      abort "Please enter a local directory and a work to add HOCR to."
    end
    work = Work.find_by_friendlier_id(work_friendlier_id)
    Dir.mkdir("#{images_local_dir}/#{work.friendlier_id}")

    assets = work.
      members.
      includes(:leaf_representative).
      where(published: true).
      order(:position).
      select do |m|
        m.leaf_representative.content_type == "image/jpeg" || m.leaf_representative&.file_derivatives(:download_full)
      end


    assets.each_with_index do |asset, index|
      filename = "#{format '%04d', index+1}-#{asset.friendlier_id}.jpg"
      File.open("#{images_local_dir}/#{work.friendlier_id}/#{filename}", "wb") do |out|
        IO.copy_stream(asset.file_derivatives[:download_large].to_io, out)
      end
    end
    File.open("#{images_local_dir}/#{work.friendlier_id}/description.txt", "wb") do |out|
      out.write work.description
    end

  end


  desc "Transcribe handwritten page images using Gemini"
  task request_gemini_transcript: :environment do
    byebug
    friendlier_id = ENV["FRIENDLIER_ID"]
    gemini_api_key = ENV["GEMINI_API_KEY"]

    unless friendlier_id.present? && gemini_api_key.present?
      abort <<~MESSAGE
        Required environment variables:
          friendlier_id
          GEMINI_API_KEY
      MESSAGE
    end


    dry_run = ENV.fetch("DRY_RUN", 'true') == 'true'

    image_folder =
      Rails.root.join("gemini_htr", "images", friendlier_id)

    output_dir =
      Rails.root.join("gemini_htr", "output", friendlier_id)

    python_script =
      Rails.root.join("python_script", "gemini_htr.py")

    python =
      ENV.fetch("PYTHON", "python3")

    model =
      ENV.fetch("GEMINI_MODEL", "gemini-3.6-flash")

    unless image_folder.directory?
      abort "Input directory does not exist: #{image_folder}"
    end

    unless python_script.file?
      abort "Python script does not exist: #{python_script}"
    end

    image_paths =
      image_folder
        .children
        .select(&:file?)
        .select { |path| %w[.png .jpg .jpeg].include?(path.extname.downcase) }
        .sort

    if image_paths.empty?
      abort "No image files found in #{image_folder}"
    end

    description_path =
      image_folder.join("description.txt")

    unless description_path.file?
      abort "Expected description file does not exist: #{description_path}"
    end

    description =
      description_path.read

    puts "Found #{image_paths.length} images."
    puts "Model: #{model}"

    system_instruction = <<~PROMPT
      You are an expert paleographer and archival OCR engine.
      You are analyzing a sequence of handwritten pages written by the same person.
      You are provided with some context about the images, as follows: "#{description}."

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
        text: "Image File: #{path.basename}"
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

    #
    # This is the complete request description sent to the Python
    # Gemini adapter.
    #
    manifest = {
      model: model,
      system_instruction: system_instruction,
      response_schema: response_schema,
      contents: contents,
      generation_config: {
        max_output_tokens: 65_536,
        media_resolution: "MEDIA_RESOLUTION_HIGH"
      }
    }

    if dry_run
      pp manifest
      abort "Dry run! Not running it."
    end


    puts "Sending request to Gemini..."

    stdout, stderr, status =
      Open3.capture3(
        {
          "GEMINI_API_KEY" => gemini_api_key
        },
        python,
        python_script.to_s,
        stdin_data: JSON.generate(manifest)
      )

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

    #
    # Everything below this point is application/output handling,
    # and therefore remains in Rails.
    #
    FileUtils.mkdir_p(output_dir)

    raw_response_path =
      output_dir.join("raw_response.json")

    raw_response_path.write(stdout)

    puts "Raw response saved to #{raw_response_path}"

    begin
      data = JSON.parse(stdout)
    rescue JSON::ParserError => e
      abort <<~MESSAGE
        Gemini's response was not valid JSON.

        The raw response has been preserved at:
          #{raw_response_path}

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
        output_dir.join("#{base_name}.txt")

      transcript_path.write(transcript)

      puts "Saved #{transcript_path.basename}"

      if notes.present?
        puts
        puts "=== PAGE NOTES: #{filename} ==="
        puts notes
        puts "============================="
        puts
      end
    end

    puts
    puts "Processing complete!"
    puts "All transcript files saved to '#{output_dir}'."
  end
end
