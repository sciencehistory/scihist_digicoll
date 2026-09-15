require 'rails_helper'

describe GeminiHandwritingTranscriptionService do
  let(:sample_transcripts) do
    [
      "Decr 17/74\n\nDear Cousin James,\n\nHave\nyou received the \"Iron Age\"?\n",
      "tried to write more\nmonday eve'\nCharles came home today.",
      "Nile & was delighted with his\nEuropean trip.\nGood night and God bless you\nYour dear Cousin\nMary A. Post.\n\nProf' Booth."
    ]
  end

  let(:asset_attribute_for_transcript) { Asset::HTR_TRANSCRIPT_ATTRIBUTE }
  let(:work_attribute_for_transcript_requests) { Work::HTR_TRANSCRIPT_REQUEST_ATTRIBUTE }

  let(:assets) { [asset1, asset2, asset3] }
  let(:asset1) { build_tiff_asset(position: 1) }
  let(:asset2) { build_tiff_asset(position: 2) }
  let(:asset3) { build_tiff_asset(position: 3) }

  let(:work) do
    create(
      :public_work,
      description: "A three-page handwritten family letter.",
      members: assets
    )
  end

  let(:service) { described_class.new(work: work) }

  let(:staged_images) { service.send(:stage_images, tmpdir) }

  let(:pages) do
    pages_for(staged_images.map { |image| image.fetch(:filename) })
  end

  before do
    allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original

    allow(ScihistDigicoll::Env)
      .to receive(:lookup)
      .with("gemini_model")
      .and_return("gemini-test-model")

    allow(ScihistDigicoll::Env)
      .to receive(:lookup)
      .with("gemini_api_key")
      .and_return("gemini-test-api-key")
  end

  after do
    if @tmpdir && File.exist?(@tmpdir)
      FileUtils.remove_entry(@tmpdir)
    end
  end

  describe "#call" do
    it "stages the work, sends it to the adapter, and attaches returned transcripts" do
      allow(service).to receive(:request_transcription) do |images|
        filenames = images.map { |image| image.fetch(:filename) }

        gemini_response(text: JSON.generate("pages" => pages_for(filenames)))
      end

      service.call

      expect(service).to have_received(:request_transcription).once

      expect(assets.map { |asset| asset.reload.public_send(asset_attribute_for_transcript) })
        .to eq(sample_transcripts)
    end
  end

  describe "#stage_images" do
    it "copies the download derivatives into ordered, asset-specific files" do
      expected_extension = Rack::Mime::MIME_TYPES.key("image/jpeg")

      expect(
        staged_images.map { |image| image.fetch(:asset) }
      ).to eq(assets)

      staged_images.each_with_index do |image, index|
        asset = assets.fetch(index)

        expect(image.fetch(:filename)).to eq(
          "#{format('%04d', index + 1)}-" \
            "#{asset.friendlier_id}#{expected_extension}"
        )

        expect(File.exist?(image.fetch(:path))).to be(true)

        expect(File.size(image.fetch(:path))).to eq(
          asset.file_derivatives.fetch(:download_large).size
        )

        expect(image.fetch(:mime_type)).to eq("image/jpeg")
      end
    end
  end

  describe "#gemini_client" do
    it "sets the Gemini API key as a request header" do
      client = service.send(:gemini_client)
      expect(client.default_options.headers["x-goog-api-key"]).to eq("gemini-test-api-key")
    end
  end

  describe "#request_transcription" do
    it "posts the built request body to the model's generateContent endpoint" do
      request_body = { some: "request body" }
      allow(GeminiContentRequestBuilder).to receive(:new)
        .with(staged_images: staged_images, work_description: work.description)
        .and_return(instance_double(GeminiContentRequestBuilder, call: request_body))

      response = gemini_response(text: "{}")

      expect(service.send(:gemini_client)).to receive(:post).with(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-test-model:generateContent",
        json: request_body
      ).and_return(response)

      expect(
        service.send(:request_transcription, staged_images)
      ).to eq(response)
    end

    it "records status and start_time on the work before invoking the adapter" do
      allow(service.send(:gemini_client)).to receive(:post).and_return(gemini_response(text: "{}"))

      now = Time.current
      travel_to(now) do
        service.send(:request_transcription, staged_images)
      end

      request_id = service.send(:transcript_request_id)
      request_log = work.reload.
        public_send(work_attribute_for_transcript_requests).
        fetch(request_id)

      expect(request_log["status"]).to eq("requested")
      expect(Time.zone.parse(request_log["start_time"])).to be_within(1.second).of(now)
    end

    it "raises AdapterError when Gemini can't be reached at all" do
      allow(service.send(:gemini_client)).to receive(:post).and_raise(HTTP::TimeoutError.new("timed out"))

      expect {
        service.send(:request_transcription, staged_images)
      }.to raise_error(described_class::AdapterError, /Could not reach Gemini/)

      request_id = service.send(:transcript_request_id)
      request_log = work.reload.
        public_send(work_attribute_for_transcript_requests).
        fetch(request_id)

      expect(request_log["status"]).to eq("error")
    end
  end

  describe "#process_results" do
    it "processes a successful adapter response and persists all transcripts" do
      service.send(
        :process_results,
        response: gemini_response(text: JSON.generate("pages" => pages)),
        staged_images: staged_images
      )

      expect(assets.map { |asset| asset.reload.public_send(asset_attribute_for_transcript) })
        .to eq(sample_transcripts)
    end
  end

  describe "#validate_adapter_result!" do
    it "accepts a successful, non-empty adapter response" do
      expect {
        service.send(
          :validate_adapter_result!,
          gemini_response(text: JSON.generate("pages" => []))
        )
      }.not_to raise_error
    end

    it "raises AdapterError when Gemini returns a non-success HTTP status" do
      expect {
        service.send(
          :validate_adapter_result!,
          gemini_response(status_code: 500, error_message: "Internal error, sorry")
        )
      }.to raise_error(
        described_class::AdapterError,
        "Gemini transcription failed with HTTP status 500: Internal error, sorry"
      )
    end
  end

  describe "#extract_generated_text!" do
    it "returns the model's generated text" do
      expect(
        service.send(:extract_generated_text!, gemini_response(text: "hello"))
      ).to eq("hello")
    end

    it "raises InvalidResponseError when the response has no text" do
      expect {
        service.send(:extract_generated_text!, gemini_response(text: nil))
      }.to raise_error(described_class::InvalidResponseError, "Gemini returned an empty response")
    end

    it "raises InvalidResponseError when the response envelope isn't valid JSON" do
      response = instance_double(
        HTTP::Response,
        status: instance_double(HTTP::Response::Status, success?: true),
        body: "not json"
      )

      expect {
        service.send(:extract_generated_text!, response)
      }.to raise_error(described_class::InvalidResponseError, /Gemini's response was not valid JSON/)
    end
  end

  describe "#extract_and_validate_pages!" do
    it "returns valid pages whose filenames match the staged images" do
      data = { "pages" => pages }

      expect(
        service.send(
          :extract_and_validate_pages!,
          data,
          staged_images: staged_images
        )
      ).to eq(pages)
    end
  end

  describe "#attach_transcripts!" do
    it "attaches each transcript to the asset identified by its staged filename" do
      service.send(
        :attach_transcripts!,
        pages.reverse,
        staged_images: staged_images
      )

      expect(assets.map { |asset| asset.reload.public_send(asset_attribute_for_transcript) })
        .to eq(sample_transcripts)
    end
  end

  describe "#eligible_assets" do
    it "returns the three published TIFF assets in position order" do
      expect(assets.map(&:content_type))
        .to eq(["image/tiff"] * 3)

      expect(assets).to all(be_published)

      expect(service.send(:eligible_assets))
        .to eq(assets)
    end
  end

  describe "#process_results regression cases" do
    it "rejects blank stdout" do
      expect_invalid_response(
        " \n\t ",
        message: "Gemini returned an empty response"
      )
    end

    it "rejects malformed JSON" do
      expect_invalid_response(
        '{"pages": [',
        message: "Gemini's response was not valid JSON."
      )
    end

    it "rejects a response with no pages key" do
      expect_invalid_response(
        JSON.generate("general_feedback" => "No pages returned"),
        message: "Gemini response does not contain a pages array"
      )
    end

    it "rejects a pages value that is not an array" do
      expect_invalid_response(
        JSON.generate("pages" => {}),
        message: "Gemini response does not contain a pages array"
      )
    end

    [
      nil,
      "not a page",
      {},
      { "filename" => "page.jpg" },
      { "filename" => "", "transcript" => "Text" },
      { "filename" => "page.jpg", "transcript" => nil },
      { "filename" => "page.jpg", "transcript" => 123 }
    ].each do |invalid_page|
      it "rejects an invalid page entry: #{invalid_page.inspect}" do
        expect_invalid_response(
          JSON.generate("pages" => [invalid_page]),
          message: "Gemini returned an invalid page entry:"
        )
      end
    end

    it "rejects a response that omits a staged page" do
      expect_invalid_response(
        JSON.generate("pages" => pages.first(2)),
        message: "Gemini returned an unexpected set of filenames."
      )
    end

    it "rejects a response containing an unexpected filename" do
      unexpected_pages = pages.map(&:dup)
      unexpected_pages.first["filename"] = "not-a-staged-file.jpg"

      expect_invalid_response(
        JSON.generate("pages" => unexpected_pages),
        message: "Gemini returned an unexpected set of filenames."
      )
    end

    it "rejects duplicate filenames even when the page count matches" do
      duplicate_pages = pages.map(&:dup)
      duplicate_pages.last["filename"] = duplicate_pages.first["filename"]

      expect_invalid_response(
        JSON.generate("pages" => duplicate_pages),
        message: "Gemini returned an unexpected set of filenames."
      )
    end
  end

  describe "#call eligibility regression cases" do
    it "rejects a work with no eligible assets before invoking the adapter" do
      allow(service).to receive(:eligible_assets).and_return([])

      expect(service).not_to receive(:request_transcription)

      expect {
        service.call
      }.to raise_error(
        described_class::IneligibleWorkError,
        /no usable images were found/
      )
    end
  end

  describe "#extension_for regression cases" do
    it "rejects an unsupported derivative MIME type" do
      derivative = double(
        "image derivative",
        mime_type: "image/x-unsupported-test"
      )

      expect {
        service.send(:extension_for, derivative)
      }.to raise_error(
        described_class::UnsupportedImageTypeError,
        "Unknown MIME type: image/x-unsupported-test"
      )
    end
  end

  def expect_invalid_response(text, message:)
    images = staged_images
    original_transcripts =
      assets.map { |asset| asset.reload.public_send(asset_attribute_for_transcript) }

    expect(service).not_to receive(:attach_transcript!)

    expect {
      service.send(
        :process_results,
        response: gemini_response(text: text),
        staged_images: images
      )
    }.to raise_error(
      described_class::InvalidResponseError,
      a_string_including(message)
    )

    expect(assets.map { |asset| asset.reload.public_send(asset_attribute_for_transcript) })
      .to eq(original_transcripts)

    request_id = service.send(:transcript_request_id)

    request_log = work.reload.
      public_send(work_attribute_for_transcript_requests).
      fetch(request_id)

    expect(request_log).to include(
      "status" => "error",
      "errors" => include(a_string_including(message))
    )
  end

  # Builds a stand-in for the HTTP::Response Gemini's generateContent endpoint
  # returns -- either a successful envelope wrapping the given generated `text`,
  # or an error envelope with the given `error_message`.
  def gemini_response(text: nil, status_code: 200, error_message: nil)
    status = instance_double(
      HTTP::Response::Status,
      success?: (200..299).cover?(status_code),
      to_s: status_code.to_s
    )

    body =
      if error_message
        JSON.generate("error" => { "message" => error_message })
      else
        JSON.generate("candidates" => [{ "content" => { "parts" => [{ "text" => text }] } }])
      end

    instance_double(HTTP::Response, status: status, body: body)
  end

  def build_tiff_asset(position:)
    create(
      :asset_with_faked_file,
      :tiff,
      position: position,
      faked_derivatives: {
        download_large: create(
          :stored_uploaded_file,
          file: File.open(
            Rails.root + "spec/test_support/images/30x30.jpg"
          ),
          content_type: "image/jpeg"
        )
      }
    )
  end

  def tmpdir
    @tmpdir ||= Dir.mktmpdir
  end

  def pages_for(filenames)
    filenames.zip(sample_transcripts).map do |filename, transcript|
      {
        "filename" => filename,
        "transcript" => transcript
      }
    end
  end
end
