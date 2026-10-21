require 'rails_helper'

describe VttJoiner do
  let(:first_vtt) do
    <<~EOS
    WEBVTT

    00:01.000 --> 00:02.000
    First words.

    01:02:03.500 --> 01:02:04.000
    Last words.
    EOS
  end

  let(:second_vtt) do
    <<~EOS
    WEBVTT

    00:00.500 --> 00:01.250
    More words.
    EOS
  end

  it "joins with shifted timestamps and one header" do
    joiner = described_class.new
    joiner.add(first_vtt)
    joiner.add(second_vtt, offset_seconds: 3600.75)

    expect(joiner.to_joined_vtt).to eq <<~EOS
    WEBVTT

    00:00:01.000 --> 00:00:02.000
    First words.

    01:02:03.500 --> 01:02:04.000
    Last words.

    01:00:01.250 --> 01:00:02.000
    More words.
    EOS

    WebVTT.from_blob(joiner.to_joined_vtt)
  end

  it "skips vtt with no cues" do
    joiner = described_class.new
    joiner.add("WEBVTT\n")
    joiner.add(second_vtt)

    expect(joiner.to_joined_vtt).to eq "WEBVTT\n\n00:00:00.500 --> 00:00:01.250\nMore words.\n"
  end
end
