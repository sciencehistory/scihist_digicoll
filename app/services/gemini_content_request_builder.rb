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

  # Prompt text lives in config/locales/gemini_transcript_prompt.en.yml, since
  # it's liable to be tweaked independently of the request-building logic.
  def system_instruction
    I18n.t(
      "gemini_content_request_builder.system_instruction",
      work_description: work_description
    )
  end

  def response_schema
    {
      type: "OBJECT",
      properties: {
        general_feedback: {
          type: "STRING",
          description: I18n.t("gemini_content_request_builder.response_schema.general_feedback_description")
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
                description: I18n.t("gemini_content_request_builder.response_schema.page_notes_description")
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

    parts << { text: I18n.t("gemini_content_request_builder.final_instruction") }

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
