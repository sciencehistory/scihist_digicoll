require 'rails_helper'
require 'marcel'

describe FfmpegExtractOpusAudio do
  let(:video_path) { "/Users/jrochkind/Documents/sample/video/SampleVideo_360x240_1mb.mp4" }
  let(:service) { described_class.new }

  it "creates opus file" do
    tempfile = service.call(video_path)

    expect(tempfile).to be_kind_of(Tempfile)
    expect(tempfile.path).to end_with(".oga")
    expect(Marcel::MimeType.for(tempfile)).to eq "audio/opus"
  ensure
    tempfile.unlink if tempfile
  end

  it "creates metadata if arg is passed" do
    added_metadata = {}
    tempfile = service.call(video_path, add_metadata: added_metadata)

    expect(added_metadata[:ffmpeg_command]).to match /ffmpeg .* -c:a libopus -b:a 16k -application voip/
    expect(added_metadata[:ffmpeg_version]).to match /\d+\.\d+/
  ensure
    tempfile.unlink if tempfile
  end
end


