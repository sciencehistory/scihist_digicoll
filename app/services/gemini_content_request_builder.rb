require 'base64'

# Builds the JSON-able request body we POST to Gemini's generateContent REST
# endpoint, for a handwriting-transcription request -- the prompt, the response
# schema, and the multimodal (text + image) parts.
#
#   GeminiContentRequestBuilder.new(
#     staged_images: staged_images,
#     work_description: work.description
#   ).call
#
# `staged_images` is the same array of hashes GeminiHandwritingTranscriptionService
# stages to a local tmpdir: each a hash with :filename, :path, and :mime_type.
class GeminiContentRequestBuilder
  def initialize(staged_images:, work_description:)
    @staged_images = staged_images
    @work_description = work_description
  end

  def call
    {
      system_instruction: { parts: [{ text: system_instruction }] },
      contents: [{ role: "user", parts: parts }],
      generation_config: {
        response_mime_type: "application/json",
        response_schema: response_schema,
        max_output_tokens: 65_536,
        media_resolution: "MEDIA_RESOLUTION_HIGH"
      }
    }
  end

  private

  attr_reader :staged_images, :work_description

  def system_instruction
    <<~PROMPT
      You are an expert paleographer and archival OCR engine.
      You are analyzing a sequence of handwritten pages written by the same person.
      You are provided with some context about the images, as follows: "#{work_description}."

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
  end

  def response_schema
    {
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
  end

  # Construct the ordered multimodal prompt. Keeping the filename immediately
  # before its corresponding image gives Gemini an explicit association between the two.
  def parts
    parts = []

    staged_images.each do |image|
      parts << { text: "Image File: #{image.fetch(:filename)}" }
      parts << image_part(image)
    end

    parts << {
      text: <<~TEXT.strip
        Please analyze all pages above, learn the handwriting style,
        and produce the requested transcript strings in JSON format.
      TEXT
    }

    parts
  end

  # A Gemini "part" for a staged image, as a base64-encoded inline blob.
  def image_part(image)
    {
      inline_data: {
        mime_type: image.fetch(:mime_type),
        data: Base64.strict_encode64(File.binread(image.fetch(:path)))
      }
    }
  end
end
