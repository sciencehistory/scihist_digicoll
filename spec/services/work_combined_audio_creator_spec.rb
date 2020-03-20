require 'rails_helper'

describe "Combined Audio" do
  let!(:work) { FactoryBot.create(:work, title: "Oral history with two interview audio segments")}

  let!(:audio_asset_1)  { create(:asset, :inline_promoted_file,
      position: 1,
      parent_id: work.id,
      file: File.open((Rails.root + "spec/test_support/audio/ice_cubes.mp3"))
    )
  }

  let!(:audio_asset_2)  { create(:asset, :inline_promoted_file,
      position: 2,
      parent_id: work.id,
      file: File.open((Rails.root + "spec/test_support/audio/double_ice_cubes.mp3"))
    )
  }

  let(:cmd) { cmd = TTY::Command.new(printer: :null)}

  it "creates combined audio derivatives" do
    expect(work.members.map(&:stored?)).to match([true, true])
    combined_audio_info = CombinedAudioDerivativeCreator.new(work).generate
    expect(combined_audio_info.start_times.count).to eq 2

    # The lengths should be correct:
    expect(combined_audio_info.start_times).to match([
      [audio_asset_1.id, 0],
      [audio_asset_2.id, 1.593469]
    ])

    # The files should be tempfiles:
    expect(combined_audio_info.mp3_file.class).to eq Tempfile
    expect(combined_audio_info.webm_file.class).to eq Tempfile

    stats_command = ['ffprobe', '-v', 'error', '-show_format', '-show_streams' ]

    # Let's use ffprobe to get some basic ino about each file:
    mp3_details   = cmd.run(*stats_command + [combined_audio_info.mp3_file.path] ).out.split("\n")
    webm_details  = cmd.run(*stats_command + [combined_audio_info.webm_file.path]).out.split("\n")

    # Are they in fact audio files?
    expect(mp3_details).to  include('format_name=mp3')
    expect(webm_details).to include('format_name=matroska,webm')

    # Is the combined length correct?

    expect(mp3_details.any?  {|x| x.include? 'duration=4.7'}).to be true
    expect(webm_details.any? {|x| x.include? 'duration=4.7'}).to be true


    # Store the fingerprint to ensure that it changes when we swap the two files...
    first_fingerprint = combined_audio_info.fingerprint
    expect(first_fingerprint.class).to eq String
    expect(first_fingerprint.length).to eq 32

    # Now swap the files. This *could* be a separate test, but we want to ensure
    # the fingerprint changes without actually
    # explicitly testing it against a fixed string
    # (which, in turn, could change if we change the recipe).

    expect(work.members.map(&:stored?)).to match([true, true])
    audio_asset_2.position = 1
    audio_asset_1.position = 2
    audio_asset_1.save!
    audio_asset_2.save!

    combined_audio_info = CombinedAudioDerivativeCreator.new(work).generate
    expect(combined_audio_info.start_times.count).to eq 2

    expect( combined_audio_info.start_times).to match([
      [audio_asset_2.id, 0],
      [audio_asset_1.id, 3.160816]
    ])

    # Get some verbose details about the files output:

    mp3_details   = cmd.run(*stats_command + [combined_audio_info.mp3_file.path] ).out.split("\n")
    webm_details  = cmd.run(*stats_command + [combined_audio_info.webm_file.path]).out.split("\n")

    # Are they audio files?
    expect(mp3_details).to  include('format_name=mp3')
    expect(webm_details).to include('format_name=matroska,webm')

    expect(mp3_details.any?  {|x| x.include? 'duration=4.7'}).to be true
    expect(webm_details.any? {|x| x.include? 'duration=4.7'}).to be true

    second_fingerprint = combined_audio_info.fingerprint
    expect(second_fingerprint.class).to eq String
    expect(second_fingerprint.length).to eq 32
    expect(second_fingerprint).not_to eq first_fingerprint
  end
end
