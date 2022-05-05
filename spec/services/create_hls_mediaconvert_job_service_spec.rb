require 'rails_helper'

# A bit hard to really test without actually talking to live MediaConvert or s3,
# but that's our goal, per our current testing practices. There ends up being a lot
# of mocking and it's kind of a mess, i'm not feeling great about these tests...
describe CreateHlsMediaconvertJobService do
  let(:asset) { create(:asset_with_faked_file, :video) }
  let(:service) { CreateHlsMediaconvertJobService.new(asset) }

  def mocked_active_encode_result
    ActiveEncode::Base.new(service.send(:input_s3_url), {}).tap do |encode|
      encode.id =  "faked-id"
      encode.state = :running
      encode.percent_complete = 0
      encode.errors = []
      encode.output = []
    end
  end

  # make the  shrine file pretend to be enough of an S3 storage to satisfy the code,
  # even though it's not actually S3 in test.
  # we're going to mock the actual AWS things later.
  before do
    without_partial_double_verification do
      allow(asset.file.storage).to receive(:bucket).and_return(OpenStruct.new(name: "fake-video-original-bucket"))
      allow(Shrine.storages[CreateHlsMediaconvertJobService::OUTPUT_SHRINE_STORAGE_KEY]).to receive(:bucket).and_return(OpenStruct.new(name: "fake-video-derivatives-bucket"))
    end
  end

  it "creates" do
    # We're going to mock active_encode entirely!
    expect(ActiveEncode::Base).to receive(:create).with(any_args) do |input, options|
      expect(input).to start_with("s3://")
      expect(input).to eq service.send(:input_s3_url)

      expect(options[:destination]).to start_with("s3://fake-video-derivatives-bucket/")
      expect(options[:destination]).to eq service.send(:output_s3_destination)

      expect(options[:use_original_url]).to be(true)
      expect(options[:outputs]).to be_present
      expect(options[:outputs].size).to eq CreateHlsMediaconvertJobService::HLS_PRESETS.size
    end.and_return(mocked_active_encode_result)

    status_model = service.call
    expect(status_model).to be_kind_of(ActiveEncodeStatus)
    expect(status_model).to be_persisted

    expect(status_model.active_encode_id).to eq("faked-id")
    expect(status_model.asset).to eq(asset)
    expect(status_model.state).to eq "running"
  end

  describe "with output storage prefix" do
    let(:storage_prefix) { Pathname.new("some/prefix") }
    before do
      without_partial_double_verification do
        allow(Shrine.storages[CreateHlsMediaconvertJobService::OUTPUT_SHRINE_STORAGE_KEY]).to(
          receive(:prefix).and_return(storage_prefix)
        )
      end
    end

    it "creates output at prefix" do
      expect(ActiveEncode::Base).to receive(:create).with(any_args) do |input, options|
        expect(options[:destination]).to start_with("s3://fake-video-derivatives-bucket/#{storage_prefix}/")
      end.and_return(mocked_active_encode_result)
      status_model = service.call
    end
  end

  describe "with a smaller original" do
    let(:asset) { create(:asset_with_faked_file, :video, faked_height: 800) }

    it "does not create too-large HLS outputs" do
      expect(ActiveEncode::Base).to receive(:create).with(any_args) do |input, options|

        expect(options[:outputs].size).to eq CreateHlsMediaconvertJobService::HLS_PRESETS.size - 1

      end.and_return(mocked_active_encode_result)

      status_model = service.call
    end
  end

  describe "tiny original" do
    let(:asset) { create(:asset_with_faked_file, :video, faked_height: 50) }

    it "still creates one output" do
      expect(ActiveEncode::Base).to receive(:create).with(any_args) do |input, options|

        expect(options[:outputs].size).to eq 1

      end.and_return(
        ActiveEncode::Base.new(service.send(:input_s3_url), {}).tap do |encode|
          encode.id =  "faked-id"
          encode.state = :running
          encode.percent_complete = 0
          encode.errors = []
          encode.output = []
        end
      )

      status_model = service.call
    end
  end

end
