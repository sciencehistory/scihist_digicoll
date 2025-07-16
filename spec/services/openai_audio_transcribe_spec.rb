require 'rails_helper'

describe OpenaiAudioTranscribe do
  let(:opus_path) { (Rails.root + "spec/test_support/audio/short_opus.oga").to_s}
  let(:service) { described_class.new }

  describe "#get_vtt" do
    it "submits API request" do
      expect(service.client.audio).to receive(:transcribe) do |args|
        expect(args.keys).to eq [:parameters]
        parameters = args[:parameters]

        expect(parameters.slice(:model, :response_format)).to eq({:model=>"whisper-1", :response_format=>"vtt"})

        expect(parameters[:file]).to be_kind_of(File)
        expect(parameters[:file].path).to eq opus_path
      end.and_return(sample_webvtt)

      file = File.open(opus_path)
      output = service.get_vtt(file)

      expect(output).to be_kind_of(String)
      expect(output).to start_with("WEBVTT")
    ensure
      file.close if file
    end

    it "raises for error" do
      expect(service.client.audio).to receive(:transcribe).and_raise(
        Faraday::BadRequestError.new(status: 400, body: "{ fake: 'body' }")
      )

      file = File.open(opus_path)
      expect {
        output = service.get_vtt(file)
      }.to raise_error(described_class::Error)
    ensure
      file.close if file
    end
  end

  describe "#get_vtt_for_asset" do
    let(:asset) { create(:asset_with_faked_file, :video, parent: build(:work, description: "This is a video described"))}

    it "submits API request with oga" do
      expect(service.client.audio).to receive(:transcribe) do |args|
        expect(args.keys).to eq [:parameters]
        parameters = args[:parameters]

        expect(parameters.slice(:model, :response_format)).to eq({:model=>"whisper-1", :response_format=>"vtt"})

        expect(parameters[:file]).to be_kind_of(Tempfile)
        expect(parameters[:file].path).to end_with(".oga")

        expect(parameters[:prompt]).to eq "This is a video described"
      end.and_return(sample_webvtt)

      webvtt = service.get_vtt_for_asset(asset)

      expect(webvtt).to be_kind_of(String)
      expect(webvtt).to start_with("WEBVTT")
    end

    describe "filtered transcript for known hallucinations" do
      let(:original) do
        <<~EOS
        WEBVTT

        00:00.000 --> 00:01.500
        This one is good

        00:01.500 --> 00:03.000
        © transcript Emily Beynon

        00:03.000 --> 00:05.000
        This one keeps some words © transcript Emily Beynon more stuff
        EOS
      end

      # While it would be best to delete whole cue if it's now blank, we aren't doing
      # that for now, keeping it quick and easy.
      let(:filtered) do
        <<~EOS
        WEBVTT

        00:00.000 --> 00:01.500
        This one is good

        00:01.500 --> 00:03.000


        00:03.000 --> 00:05.000
        This one keeps some words
        EOS
      end

      it "filters" do
        expect(service.client.audio).to receive(:transcribe).and_return(original)

        webvtt = service.get_vtt_for_asset(asset)

        expect(webvtt).to eq filtered

        # and make sure it's really parseable
        WebVTT.from_blob(filtered)
      end
    end
  end

  describe "#get_and_store_vtt_for_asset" do
    let(:asset) { create(:asset_with_faked_file, :video, parent: build(:work, description: "This is a video described"))}

    it "stores as derivative and metadata" do
      expect(service.client.audio).to receive(:transcribe) do |args|
        expect(args.keys).to eq [:parameters]
        parameters = args[:parameters]

        expect(parameters.slice(:model, :response_format)).to eq({:model=>"whisper-1", :response_format=>"vtt"})

        expect(parameters[:file]).to be_kind_of(Tempfile)
        expect(parameters[:file].path).to end_with(".oga")
      end.and_return(sample_webvtt)

      service.get_and_store_vtt_for_asset(asset)

      expect(asset.asr_webvtt_str).to eq sample_webvtt

      metadata = asset.file_derivatives[Asset::ASR_WEBVTT_DERIVATIVE_KEY].metadata

      expect(metadata["mime_type"]).to eq "text/vtt"

      expect(metadata["asr_engine"]).to eq({
        "api" => "OpenAI transcribe",
        "model" => "whisper-1",
        "prompt" => "This is a video described"
      })
      expect(metadata["created_at"]).to be_present
    end

    describe "with work with english language only" do
      let(:asset) { create(:asset_with_faked_file, :video, parent: create(:work, language: ["English"]))}

      it "can submit with lang" do
        expect(service.client.audio).to receive(:transcribe) do |args|
          expect(args.keys).to eq [:parameters]
          parameters = args[:parameters]

          expect(parameters.slice(:model, :response_format)).to eq({:model=>"whisper-1", :response_format=>"vtt"})

          expect(parameters[:language]).to eq "en"

          expect(parameters[:file]).to be_kind_of(Tempfile)
          expect(parameters[:file].path).to end_with(".oga")
        end.and_return(sample_webvtt)

        service.get_and_store_vtt_for_asset(asset)

        expect(asset.file_derivatives[Asset::ASR_WEBVTT_DERIVATIVE_KEY].metadata["asr_engine"]).to eq({
        "api" => "OpenAI transcribe",
        "model" => "whisper-1",
        "language" => "en"
      })
      end
    end
  end

  let(:sample_webvtt) do
    <<~EOS
    WEBVTT

    00:00.000 --> 00:01.500
    Hello, welcome to the podcast.

    00:01.500 --> 00:03.000
    Today we're going to talk about AI.

    00:03.000 --> 00:05.000
    Let's get started.
    EOS
  end
end
