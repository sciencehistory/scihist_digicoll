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

  it "does not cut audio shorter than chunk size" do
    expect(described_class.new(chunk_size: 20, cut_point_seek_window: 2).cut_points(audio_file.path, 10)).to eq []
  end

  it "cuts in the middle of nearby silence" do
    cuts = described_class.new(chunk_size: 4.5, cut_point_seek_window: 2).cut_points(audio_file.path, 10)
    expect(cuts.first).to be_within(0.3).of(5)
  end

  it "cuts at target when no silence nearby" do
    cuts = described_class.new(chunk_size: 3, cut_point_seek_window: 0.5).cut_points(audio_file.path, 10)
    expect(cuts.first).to eq 3
  end

  it "yields chunks with offsets" do
    chunks = []
    described_class.new(chunk_size: 5, cut_point_seek_window: 2).split(audio_file.path, duration_seconds: 10) do |file:, start_seconds:, index:|
      chunks << [index, start_seconds, File.exist?(file.path), duration_of(file.path)]
    end

    expect(chunks.length).to eq 2
    expect(chunks.map(&:first)).to eq [0, 1]
    expect(chunks.first[1]).to eq 0
    expect(chunks.last[1]).to be_within(0.3).of(5)
    expect(chunks.map(&:last).sum).to be_within(0.3).of(10)
    expect(chunks.map { |c| c[2] }).to all(be true)
  end
end
