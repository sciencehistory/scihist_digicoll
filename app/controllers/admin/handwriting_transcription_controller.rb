class Admin::HandwritingTranscriptionController < AdminController

  before_action :set_work

  #class_attribute :extract_pdf_text_command,
  #  default: ScihistDigicoll::Util.prefix_python_exec_command("./python_script/gemini_htr.py")

  def request_handwriting_transcription

    # http://localhost:3000/admin/works/db78tc078#tab=nav-ocr

    gemini_api_key =    ScihistDigicoll::Env.lookup("gemini_api_key")

    assets = @work.
      members.
      includes(:leaf_representative).
      where(published: true).
      order(:position).
      select do |m|
        m.leaf_representative.content_type == "image/jpeg" || m.leaf_representative&.file_derivatives(:download_full)
      end

    Dir.mktmpdir do |dir|
      # Use 'dir' to get the full path string of your temp directory
      puts dir # => "/tmp/d20260825-12345-abcde"
      
      image_paths = []
      description_path = "#{dir}/description.txt" 

      assets.each_with_index do |asset, index|
        filename = "#{format '%04d', index+1}-#{asset.friendlier_id}.jpg"
        File.open("#{dir}/#{filename}", "wb") do |out|
          IO.copy_stream(asset.file_derivatives[:download_large].to_io, out)
        end
        image_paths << "#{dir}/#{filename}"
      end

      pp image_paths
      pp description_path

      manifest = gemerate_manifest(image_paths)
      pp manifest


      python_command =
        ScihistDigicoll::Util.prefix_python_exec_command(
          "./python_script/gemini_htr.py"
        )

      puts "Sending request to Gemini..."

      stdout, stderr, status = Open3.capture3(
          {
            "GEMINI_API_KEY" => gemini_api_key
          },
          python_command,
          stdin_data: JSON.generate(manifest),
          chdir: Rails.root.to_s
        )

      process_results(stdout: stdout, stderr: stderr, status: status)

      anchor = "tab=nav-ocr"
      redirect_to admin_work_path(@work), flash: { notice: "A transcript of this work has been requested." }, anchor: anchor
    end
  end


  private


  def process_results( stdout: stdout, stderr: stderr, status: status)
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

    byebug

    #
    # Everything below this point is application/output handling,
    # and therefore remains in Rails.
    #
    output_dir_name = "gemini_results_#{@work.friendlier_id}"
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

      transcript_path = File.join(output_dir_name, "#{base_name}.txt")
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


    # TODO: refactor this (DRY from above)
    assets = @work.
      members.
      includes(:leaf_representative).
      where(published: true).
      order(:position).
      select do |m|
        m.leaf_representative.content_type == "image/jpeg" || m.leaf_representative&.file_derivatives(:download_full)
      end


    unless assets.count == data.fetch("pages", []).count
      abort "Wrong number of transcripts."
    end


    pages = data.fetch("pages", [])

    transcript_map = assets.map { |a| [
      a.friendlier_id,
      pages.find {|p| p["filename"].include? a.friendlier_id }
    ] }.to_h


    # do an asset transaction here
    assets.each do |asset|
      friendlier_id = asset.friendlier_id
      transcript = transcript_map[friendlier_id]['transcript']
      puts "Attaching transcript to #{friendlier_id}."
      asset.update!({transcription: transcript})
    end


    ###############################.  END ATTACHING

    puts "Processing complete!"
  end

  def gemerate_manifest(image_paths)

    system_instruction = <<~PROMPT
      You are an expert paleographer and archival OCR engine.
      You are analyzing a sequence of handwritten pages written by the same person.
      You are provided with some context about the images, as follows: "#{@work.description}."

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

    #
    # This is the complete request description sent to the Python
    # Gemini adapter.
    #
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

  # def set_audio_asr_enabled
  #   @asset.update!(audio_asr_enabled: params[:asset][:audio_asr_enabled])

  #   # If we don't have an ASR, and we just enabled it, then queue a job
  #   # to create it.
  #   if !@asset.asr_webvtt? && @asset.audio_asr_enabled_previous_change&.last
  #     OpenaiAudioTranscribeJob.perform_later(@asset)
  #   end

  #   redirect_to admin_asset_path(@asset)
  # end

  # def upload_corrected_vtt
  #   # validate, will raise if invalid from inside, or if we raise for no cues
  #   unless OralHistoryContent::OhmsXml::VttTranscript.new(
  #     params[:asset_derivative][Asset::CORRECTED_WEBVTT_DERIVATIVE_KEY].read,
  #     auto_correct_format: false
  #   ).cues.length > 0
  #     raise WebVTT::MalformedFile.new("Has no cues, probably malformed")
  #   end

  #   @asset.file_attacher.add_persisted_derivatives({
  #      Asset::CORRECTED_WEBVTT_DERIVATIVE_KEY =>
  #       params[:asset_derivative][Asset::CORRECTED_WEBVTT_DERIVATIVE_KEY]
  #   })

  #   redirect_to admin_asset_path(@asset)
  # rescue WebVTT::MalformedFile => e
  #   redirect_to admin_asset_path(@asset), flash: { error: "Could not upload corrected VTT file: #{e.message}" }
  # end

  # def delete_transcript
  #   unless params[:derivative_key].to_sym.in?([Asset::ASR_WEBVTT_DERIVATIVE_KEY, Asset::CORRECTED_WEBVTT_DERIVATIVE_KEY])
  #     raise ArgumentError.new("param derivative_key needs to be #{Asset::ASR_WEBVTT_DERIVATIVE_KEY} or #{Asset::CORRECTED_WEBVTT_DERIVATIVE_KEY}, not `#{params[:derivative_key]}`")
  #   end

  #   @asset.remove_derivatives(params[:derivative_key].to_sym)

  #   redirect_to admin_asset_path(@asset)
  # end


  def set_work
    @work = Work.find_by_friendlier_id(params[:work_id])
  end
end
