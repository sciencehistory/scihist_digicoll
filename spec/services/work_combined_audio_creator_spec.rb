require 'rails_helper'

describe "Combined Audio" do
  let!(:work) { FactoryBot.create(:work, title: "Oral history with two interview audio segments")}
  let(:cmd) { cmd = TTY::Command.new(printer: :null)}

  context "one viable mp3" do
    let!(:mp3)  { create(:asset, :inline_promoted_file,
        position: 1,
        parent_id: work.id,
        file: File.open((Rails.root + "spec/test_support/audio/5-seconds-of-silence.mp3"))
      )
    }
    it "creates combined audio derivative", queue_adapter: :inline do
      expect(work.members.map(&:stored?)).to match([true])
      audio_file = work.members.first.file
      expect(audio_file.metadata['bitrate']).to be_a_kind_of(Integer)
      combined_audio_info = CombinedAudioDerivativeCreator.new(work).generate
      expect(combined_audio_info.start_times.count).to eq 1
      expect(combined_audio_info.start_times).to match([[mp3.id, 0]])
      expect(combined_audio_info.m4a_file.class).to eq Tempfile
      stats_command = ['ffprobe', '-v', 'error', '-show_format', '-show_streams' ]
      m4a_details   = cmd.run(*stats_command + [combined_audio_info.m4a_file.path] ).out.split("\n")
      expect(m4a_details).to  include('codec_tag_string=mp4a')
      expect(m4a_details).to  include('codec_name=aac')
      expect(m4a_details).to  include('format_long_name=QuickTime / MOV')
      expect(m4a_details.any?  {|x| x.include? 'duration=5.0'}).to be true
      fingerprint = combined_audio_info.fingerprint
      expect(fingerprint.class).to eq String
      expect(fingerprint.length).to eq 32
    end
  end

  context "two viable mp3s" do
    let!(:mp3_1)  { create(:asset, :inline_promoted_file,
        position: 1,
        parent_id: work.id,
        file: File.open((Rails.root + "spec/test_support/audio/5-seconds-of-silence.mp3"))
      )
    }
    let!(:mp3_2)  { create(:asset, :inline_promoted_file,
        position: 2,
        parent_id: work.id,
        file: File.open((Rails.root + "spec/test_support/audio/10-seconds-of-silence.mp3"))
      )
    }

    it "creates combined audio derivatives", queue_adapter: :inline do
      expect(work.members.map(&:stored?)).to match([true, true])
      expect(work.members.first.file.metadata['bitrate']).to be_a_kind_of(Integer)
      expect(work.members.second.file.metadata['bitrate']).to be_a_kind_of(Integer)

      combined_audio_info = CombinedAudioDerivativeCreator.new(work).generate
      expect(combined_audio_info.start_times.count).to eq 2

      # The lengths should be correct:
      expect(combined_audio_info.start_times).to match([
        [mp3_1.id, 0],
        [mp3_2.id, 5.184]
      ])

      # The files should be tempfiles:
      expect(combined_audio_info.m4a_file.class).to eq Tempfile

      stats_command = ['ffprobe', '-v', 'error', '-show_format', '-show_streams' ]

      # Let's use ffprobe to get some basic info about each file:
      m4a_details   = cmd.run(*stats_command + [combined_audio_info.m4a_file.path] ).out.split("\n")

      # Are they in fact audio files?
      expect(m4a_details).to  include('codec_tag_string=mp4a')
      expect(m4a_details).to  include('codec_name=aac')
      expect(m4a_details).to  include('format_long_name=QuickTime / MOV')
      # Is the combined length correct?
      expect(m4a_details.any?  {|x| x.include? 'duration=15.0'}).to be true


      # Store the fingerprint to ensure that it changes when we swap the two files...
      first_fingerprint = combined_audio_info.fingerprint
      expect(first_fingerprint.class).to eq String
      expect(first_fingerprint.length).to eq 32

      # Now swap the files. This *could* be a separate test, but we want to ensure
      # the fingerprint changes without actually
      # explicitly testing it against a fixed string
      # (which, in turn, could change if we change the recipe).

      expect(work.members.map(&:stored?)).to match([true, true])
      mp3_2.position = 1
      mp3_1.position = 2
      mp3_1.save!
      mp3_2.save!

      combined_audio_info = CombinedAudioDerivativeCreator.new(work).generate
      expect(combined_audio_info.start_times.count).to eq 2

      expect( combined_audio_info.start_times).to match([
        [mp3_2.id, 0],
        [mp3_1.id, 10.152]
      ])

      # Get some verbose details about the files output:

      m4a_details   = cmd.run(*stats_command + [combined_audio_info.m4a_file.path] ).out.split("\n")

      # Are they audio files?
      expect(m4a_details).to  include('codec_tag_string=mp4a')
      expect(m4a_details).to  include('codec_name=aac')
      expect(m4a_details).to  include('format_long_name=QuickTime / MOV')
      expect(m4a_details.any?  {|x| x.include? 'duration=15.0'}).to be true

      second_fingerprint = combined_audio_info.fingerprint
      expect(second_fingerprint.class).to eq String
      expect(second_fingerprint.length).to eq 32
      expect(second_fingerprint).not_to eq first_fingerprint
    end
  end

  context "two broken flacs" do
    let!(:flac_zero_bytes)  { create(:asset, :inline_promoted_file,
        position: 1,
        parent_id: work.id,
        file: File.open((Rails.root + "spec/test_support/audio/zero_bytes.flac"))
      )
    }
    let!(:flac_bad_metadata)  { create(:asset, :inline_promoted_file,
        position: 2,
        parent_id: work.id,
        file: File.open((Rails.root + "spec/test_support/audio/bad_metadata.flac"))
      )
    }

    it "fails quickly and provides a helpful error message", queue_adapter: :inline do
      expect(work.members.map(&:stored?)).to match([true, true])
      expect(work.members.first.file.metadata['bitrate']).to be_nil
      expect(work.members.second.file.metadata['bitrate']).to be_nil
      creator = CombinedAudioDerivativeCreator.new(work)
      combined_audio_info = creator.generate
      # The first empty mp3 should not even be counted as an available audio member:
      expect(creator.available_members_count).to eq 1
      expect(combined_audio_info.errors).to eq "bad_metadata.flac: audio duration is unavailable or zero; bad_metadata.flac: audio bitrate or sample rate is unavailable"
      expect(combined_audio_info.start_times).to be_nil
      expect(combined_audio_info.m4a_file).to be_nil
      expect(combined_audio_info.fingerprint).to be_nil
    end
  end
end