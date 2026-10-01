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

  # Prompt text lives in app/views/gemini_content_request_builder/, since it's
  # liable to be tweaked independently of the request-building logic.
  def system_instruction
    ApplicationController.render(
      template: "gemini_content_request_builder/system_instruction",
      locals: { work_description: work_description },
      formats: [:text]
    )
  end

  def final_instruction
    ApplicationController.render(
      template: "gemini_content_request_builder/final_instruction",
      formats: [:text]
    ).strip
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

    parts << { text: final_instruction }

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
