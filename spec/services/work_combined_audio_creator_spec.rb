require 'rails_helper'

describe "Combined Audio" do
  # We need to set the friendlier_id explicitly, because it's part of the fingerprint recipe.
  let!(:work) { FactoryBot.create(:work, title: "top", friendlier_id: '1ciyp1i')}
  let(:audio_file_path) { Rails.root.join("spec/test_support/audio/ice_cubes.mp3")}
  let(:audio_file_sha512) { Digest::SHA512.hexdigest(File.read(audio_file_path)) }
  let!(:audio_asset_1) { FactoryBot.create(:asset, file: File.open(audio_file_path), parent_id: work.id) }
  let!(:audio_asset_2) { FactoryBot.create(:asset, file: File.open(audio_file_path), parent_id: work.id) }

  before do
    audio_asset_1.file.metadata['sha512'] = audio_file_sha512
    audio_asset_1.save!
    audio_asset_2.file.metadata['sha512'] = audio_file_sha512
    audio_asset_2.save!
    # Not sure why we need to build this pause in.
    sleep 1
  end

  it "creates combined audio derivatives" do
    combined_audio_info = CombinedAudioDerivativeCreator.new(work).generate
    expect(combined_audio_info[:component_metadata][:durations]).to match(["1.593469", "1.593469"])
    cmd = TTY::Command.new(printer: :null)
    stats_command = ['ffprobe', '-v', 'error', '-show_format', '-show_streams' ]
    mp3_details   = cmd.run(*stats_command + [combined_audio_info[:combined_audio_mp3_data   ]]).out.split("\n")
    webm_details  = cmd.run(*stats_command + [combined_audio_info[:combined_audio_webm_data   ]]).out.split("\n")
    expect(mp3_details).to  include('format_name=mp3')
    expect(webm_details).to include('format_name=matroska,webm')
    expect(mp3_details.any?  {|x| x.include? 'duration=3.1'}).to be true
    expect(webm_details.any? {|x| x.include? 'duration=3.1'}).to be true
    # The fingerprint depends on the title, friendlier_id, and audio_file_sha512.
    # As long as those are fixed, you can count on this fingerprint.
    expect(combined_audio_info[:fingerprint]).to eq '5077e167ad28bac16fb44f83d263fb52'
  end
end
