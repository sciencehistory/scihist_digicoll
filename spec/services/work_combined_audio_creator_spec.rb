require 'rails_helper'
#require "shrine/storage/memory"

describe "Combined Audio" do
  # We need to set the friendlier_id explicitly, because it's part of the fingerprint recipe.
  let!(:work) { FactoryBot.create(:work, title: "top", friendlier_id: '1ciyp1i')}


  let(:audio_file_1_path) { Rails.root.join("spec/test_support/audio/ice_cubes.mp3")}
  let(:audio_file_2_path) { Rails.root.join("spec/test_support/audio/double_ice_cubes.mp3")}
  let(:audio_file_1_sha512) { Digest::SHA512.hexdigest(File.read(audio_file_1_path)) }
  let(:audio_file_2_sha512) { Digest::SHA512.hexdigest(File.read(audio_file_2_path)) }
  sleep 2


  let!(:audio_asset_1) { FactoryBot.create(:asset, file: File.open(audio_file_1_path, "rb"), position: 1, parent_id: work.id, id: 'ddbd1a8d-c2eb-47b3-85a4-11b4ffb41719') }
  let!(:audio_asset_2) { FactoryBot.create(:asset, file: File.open(audio_file_2_path, "rb"), position: 2, parent_id: work.id, id: 'df773502-56d7-4756-a58c-b1f479910e97') }


  before do
    audio_asset_1.file.metadata['sha512'] = audio_file_1_sha512
    audio_asset_1.save!
    audio_asset_2.file.metadata['sha512'] = audio_file_2_sha512
    audio_asset_2.save!
    work.save!
  end

  it "creates combined audio derivatives" do
    expect(work.members.map(&:stored?)).to match([true, true])
    combined_audio_info = CombinedAudioDerivativeCreator.new(work).generate
    expect(combined_audio_info.start_times.count).to eq 2
    expect(combined_audio_info.start_times).to match([["ddbd1a8d-c2eb-47b3-85a4-11b4ffb41719", 0], ["df773502-56d7-4756-a58c-b1f479910e97", 1.593469]])
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
    expect(work.members.map(&:stored?)).to match([true, true])
    combined_audio_info = CombinedAudioDerivativeCreator.new(work).generate
    expect(combined_audio_info.start_times.count).to eq 2
    expect(combined_audio_info.start_times).to match([["df773502-56d7-4756-a58c-b1f479910e97", 0], ["ddbd1a8d-c2eb-47b3-85a4-11b4ffb41719", 3.160816]])
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
    expect(combined_audio_info.fingerprint).to eq '8f8e8b470b21b18372f1ee1d5548a7e6'
  end
end
