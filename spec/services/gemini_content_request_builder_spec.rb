require 'rails_helper'

describe GeminiContentRequestBuilder do
  let(:image_path) { (Rails.root + "spec/test_support/images/30x30.jpg").to_s }

  let(:staged_images) do
    [
      { filename: "0001-a.jpg", path: image_path, mime_type: "image/jpeg" },
      { filename: "0002-b.jpg", path: image_path, mime_type: "image/jpeg" }
    ]
  end

  let(:work_description) { "A three-page handwritten family letter." }

  let(:builder) { described_class.new(staged_images: staged_images, work_description: work_description) }

  describe "#call" do
    it "builds an ordered multimodal generateContent request body for all staged images" do
      body = builder.call

      expect(body[:system_instruction][:parts].first[:text])
        .to include(work_description)

      expect(
        body.dig(:generation_config, :response_schema, :properties, :pages, :items, :required)
      ).to eq(["filename", "transcript"])

      expect(body[:generation_config]).to include(
        response_mime_type: "application/json",
        max_output_tokens: 65_536,
        media_resolution: "MEDIA_RESOLUTION_HIGH"
      )

      expect(body[:contents].length).to eq(1)
      expect(body[:contents].first[:role]).to eq("user")

      parts = body[:contents].first[:parts]

      expected_image_parts =
        staged_images.flat_map do |image|
          [
            { text: "Image File: #{image.fetch(:filename)}" },
            {
              inline_data: {
                mime_type: image.fetch(:mime_type),
                data: Base64.strict_encode64(File.binread(image.fetch(:path)))
              }
            }
          ]
        end

      expect(parts.first(expected_image_parts.length)).to eq(expected_image_parts)

      expect(parts.last).to eq(
        text: <<~TEXT.strip
          Please analyze all pages above, learn the handwriting style,
          and produce the requested transcript strings in JSON format.
        TEXT
      )
    end

    it "returns no image parts when there are no staged images" do
      body = described_class.new(staged_images: [], work_description: work_description).call

      expect(body[:contents].first[:parts]).to eq(
        [
          text: <<~TEXT.strip
            Please analyze all pages above, learn the handwriting style,
            and produce the requested transcript strings in JSON format.
          TEXT
        ]
      )
    end
  end
end
