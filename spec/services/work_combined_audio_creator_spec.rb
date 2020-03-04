require 'rails_helper'

describe "Combined Audio" do
  # We need to set the friendlier_id explicitly, because it's part of the fingerprint recipe.
  let!(:work) { FactoryBot.create(:work, title: "top", friendlier_id: '1ciyp1i')}

  let!(:audio_asset_1)  { create(:asset, :inline_promoted_mp3_file_1,
    position: 1,
    parent_id: work.id,
    id: 'ddbd1a8d-c2eb-47b3-85a4-11b4ffb41719')
  }

  let!(:audio_asset_2)  { create(:asset, :inline_promoted_mp3_file_2,
    position: 2,
    parent_id: work.id,
    id: 'df773502-56d7-4756-a58c-b1f479910e97')
  }

  it "creates combined audio derivatives" do
    expect(work.members.map(&:stored?)).to match([true, true])
    combined_audio_info = CombinedAudioDerivativeCreator.new(work).generate
    expect(combined_audio_info.start_times.count).to eq 2
    expect(combined_audio_info.start_times).to match([
      ["ddbd1a8d-c2eb-47b3-85a4-11b4ffb41719", 0],
      ["df773502-56d7-4756-a58c-b1f479910e97", 1.593469]
    ])
    cmd = TTY::Command.new(printer: :null)
    stats_command = ['ffprobe', '-v', 'error', '-show_format', '-show_streams' ]
    mp3_details   = cmd.run(*stats_command + [combined_audio_info.mp3_file.path] ).out.split("\n")
    webm_details  = cmd.run(*stats_command + [combined_audio_info.webm_file.path]).out.split("\n")
    expect(mp3_details).to  include('format_name=mp3')
    expect(webm_details).to include('format_name=matroska,webm')

    expect(mp3_details.any?  {|x| x.include? 'duration=4.7'}).to be true
    expect(webm_details.any? {|x| x.include? 'duration=4.7'}).to be true
    # The fingerprint depends on the title, friendlier_id, and audio_file_sha512.
    # As long as those are fixed, you can count on this fingerprint.
    expect(combined_audio_info.fingerprint).to eq '8402b003dd07775a83b1a000b3319fd9'
  end

  it "changes the fingerprint if the components are exchanged" do
    expect(work.members.map(&:stored?)).to match([true, true])
    audio_asset_2.position = 1
    audio_asset_1.position = 2
    audio_asset_1.save!
    audio_asset_2.save!
    combined_audio_info = CombinedAudioDerivativeCreator.new(work).generate
    expect(combined_audio_info.start_times.count).to eq 2
    expect(combined_audio_info.start_times).to match([
      ["df773502-56d7-4756-a58c-b1f479910e97", 0],
      ["ddbd1a8d-c2eb-47b3-85a4-11b4ffb41719", 3.160816]
    ])
    cmd = TTY::Command.new(printer: :null)
    stats_command = ['ffprobe', '-v', 'error', '-show_format', '-show_streams' ]
    mp3_details   = cmd.run(*stats_command + [combined_audio_info.mp3_file.path] ).out.split("\n")
    webm_details  = cmd.run(*stats_command + [combined_audio_info.webm_file.path]).out.split("\n")
    expect(mp3_details).to  include('format_name=mp3')
    expect(webm_details).to include('format_name=matroska,webm')
    expect(mp3_details.any?  {|x| x.include? 'duration=4.7'}).to be true
    expect(webm_details.any? {|x| x.include? 'duration=4.7'}).to be true
    expect(combined_audio_info.fingerprint).to eq '8f8e8b470b21b18372f1ee1d5548a7e6'
  end
end
