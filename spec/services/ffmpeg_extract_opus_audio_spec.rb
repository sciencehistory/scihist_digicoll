require 'rails_helper'
require 'marcel'

describe FfmpegExtractOpusAudio do
  let(:video_path) { Rails.root.join("spec/test_support/video/sample_video.mp4").to_s }
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


