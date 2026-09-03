require 'rails_helper'

describe GeminiHandwritingTranscriptionService do
  let(:sample_transcripts) do
    [
      "Decr 17/74\n\nDear Cousin James,\n\nHave\nyou received the \"Iron Age\"?\n",
      "tried to write more\nmonday eve'\nCharles came home today.",
      "Nile & was delighted with his\nEuropean trip.\nGood night and God bless you\nYour dear Cousin\nMary A. Post.\n\nProf' Booth."
    ]
  end

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

  let(:successful_status) do
    instance_double(Process::Status, success?: true, exitstatus: 0)
  end

  let(:staged_images) { service.send(:stage_images, tmpdir) }

  let(:pages) do
    pages_for(staged_images.map { |image| image.fetch(:filename) })
  end

  before do
    allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original

    allow(ScihistDigicoll::Env).
      to receive(:lookup).
      with("gemini_model").
      and_return("gemini-test-model")

    allow(ScihistDigicoll::Env).
      to receive(:lookup).
      with("gemini_api_key").
      and_return("gemini-test-api-key")
  end

  after do
    if @tmpdir && File.exist?(@tmpdir)
      FileUtils.remove_entry(@tmpdir)
    end
  end

  describe "#call" do
    it "stages the work, sends it to the adapter, and attaches returned transcripts" do
      allow(service).to receive(:request_transcription) do |manifest|
        filenames = filenames_from_manifest(manifest)

        [
          JSON.generate("pages" => pages_for(filenames)),
          "",
          successful_status
        ]
      end

      service.call

      expect(service).to have_received(:request_transcription).once

      expect(assets.map { |asset| asset.reload.htr_transcript }).
        to eq(sample_transcripts)
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
      end
    end
  end

  describe "#request_transcription" do
    it "passes the manifest and Gemini API key to the Python adapter" do
      manifest = JSON.generate("some" => "manifest")
      python_command = "test-python-command"
      adapter_result = ["stdout", "stderr", successful_status]

      expect(ScihistDigicoll::Util).
        to receive(:prefix_python_exec_command).
        with("./python_script/gemini_htr.py").
        and_return(python_command)

      expect(Open3).to receive(:capture3).with(
        { "GEMINI_API_KEY" => "gemini-test-api-key" },
        python_command,
        stdin_data: manifest,
        chdir: Rails.root.to_s
      ).and_return(adapter_result)

      expect(
        service.send(:request_transcription, manifest)
      ).to eq(adapter_result)
    end
  end

  describe "#process_results" do
    it "processes a successful adapter response and persists all transcripts" do
      service.send(
        :process_results,
        stdout: JSON.generate("pages" => pages),
        stderr: "",
        status: successful_status,
        staged_images: staged_images
      )

      expect(assets.map { |asset| asset.reload.htr_transcript }).
        to eq(sample_transcripts)
    end
  end

  describe "#validate_adapter_result!" do
    it "accepts a successful, non-empty adapter response" do
      expect {
        service.send(
          :validate_adapter_result!,
          stdout: JSON.generate("pages" => []),
          status: successful_status
        )
      }.not_to raise_error
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

      expect(assets.map { |asset| asset.reload.htr_transcript }).
        to eq(sample_transcripts)
    end
  end

  describe "#generate_manifest" do
    it "builds an ordered multimodal manifest for all staged images" do
      manifest =
        JSON.parse(service.send(:generate_manifest, staged_images))

      expect(manifest.fetch("model")).
        to eq("gemini-test-model")

      expect(manifest.fetch("system_instruction")).
        to include(work.description)

      expect(
        manifest.dig(
          "response_schema",
          "properties",
          "pages",
          "items",
          "required"
        )
      ).to eq(["filename", "transcript"])

      expect(manifest.fetch("generation_config")).to eq(
        "max_output_tokens" => 65_536,
        "media_resolution" => "MEDIA_RESOLUTION_HIGH"
      )

      expected_image_contents =
        staged_images.flat_map do |image|
          [
            {
              "type" => "text",
              "text" => "Image File: #{image.fetch(:filename)}"
            },
            {
              "type" => "image",
              "path" => image.fetch(:path)
            }
          ]
        end

      expect(
        manifest.fetch("contents").first(expected_image_contents.length)
      ).to eq(expected_image_contents)

      expect(manifest.fetch("contents").last).to eq(
        "type" => "text",
        "text" => <<~TEXT.strip
          Please analyze all pages above, learn the handwriting style,
          and produce the requested transcript strings in JSON format.
        TEXT
      )
    end
  end

  describe "#eligible_assets" do
    it "returns the three published TIFF assets in position order" do
      expect(assets.map(&:content_type)).
        to eq(["image/tiff"] * 3)

      expect(assets).to all(be_published)

      expect(service.send(:eligible_assets)).
        to eq(assets)
    end
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

  def filenames_from_manifest(manifest)
    JSON.parse(manifest).fetch("contents").filter_map do |content|
      next unless content["type"] == "text"

      content["text"][/\AImage File: (.+)\z/, 1]
    end
  end
end