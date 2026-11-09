require 'rails_helper'

describe AudioSilenceSplitter do
  # 10 second tone, with silence from 4 to 6 seconds
  let(:audio_file) do
    Tempfile.new(["splitter_spec", ".oga"]).tap do |f|
      TTY::Command.new(printer: :null).run(
        "ffmpeg", "-nostdin", "-y", "-f", "lavfi", "-i", "sine=frequency=440:duration=10",
        "-af", "volume=enable='between(t,4,6)':volume=0", "-c:a", "libopus", f.path
      )
    end
  end
  after { audio_file.close! }

  def duration_of(path)
    out, _err = TTY::Command.new(printer: :null).run("ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path)
    Float(out.strip)
  end

  it "does not cut audio shorter than max segment size" do
    expect(described_class.new(max_segment_length: 20, cut_point_seek_window: 2).cut_points(audio_file.path, 10)).to eq []
  end

  it "cuts in the middle of nearby silence" do
    cuts = described_class.new(max_segment_length: 6, cut_point_seek_window: 2).cut_points(audio_file.path, 10)
    expect(cuts.first).to be_within(0.3).of(5)
  end

  it "cuts at target when no silence nearby" do
    expect(Rails.logger).to receive(:warn).with(/Asset abc123.*no silence/).at_least(:once)

    cuts = described_class.new(max_segment_length: 4, cut_point_seek_window: 0.5, log_label: "Asset abc123").cut_points(audio_file.path, 10)
    # 3 equal segments of 10/3
    expect(cuts).to match [be_within(0.001).of(10.0 / 3), be_within(0.001).of(20.0 / 3)]
  end

  it "makes equal segments, none over max" do
    allow(Rails.logger).to receive(:warn)

    cuts = described_class.new(max_segment_length: 4).cut_points(audio_file.path, 10)
    bounds = [0] + cuts + [10]
    lengths = bounds.each_cons(2).map { |a, b| b - a }

    expect(lengths.length).to eq 3
    expect(lengths).to all(be <= 4)
  end

  it "leaves slack to seek silence when duration is an exact multiple of max" do
    cuts = described_class.new(max_segment_length: 5).cut_points(audio_file.path, 10)
    bounds = [0] + cuts + [10]
    lengths = bounds.each_cons(2).map { |a, b| b - a }

    expect(lengths.length).to eq 3
    expect(lengths).to all(be < 5)
  end

  it "never exceeds max even with an oversized seek window" do
    cuts = described_class.new(max_segment_length: 6, cut_point_seek_window: 100).cut_points(audio_file.path, 10)
    bounds = [0] + cuts + [10]
    expect(bounds.each_cons(2).map { |a, b| b - a }).to all(be <= 6)
  end

  it "yields segments with offsets" do
    segments = []
    described_class.new(max_segment_length: 6, cut_point_seek_window: 2).split(audio_file.path, duration_seconds: 10) do |file:, start_seconds:, index:|
      segments << [index, start_seconds, File.exist?(file.path), duration_of(file.path)]
    end

    expect(segments.length).to eq 2
    expect(segments.map(&:first)).to eq [0, 1]
    expect(segments.first[1]).to eq 0
    expect(segments.last[1]).to be_within(0.3).of(5)
    expect(segments.map(&:last).sum).to be_within(0.3).of(10)
    expect(segments.map { |c| c[2] }).to all(be true)
  end
end
