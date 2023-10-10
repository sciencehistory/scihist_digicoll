require 'rails_helper'

describe "Combined Audio" do
  let!(:work) { FactoryBot.create(:work, title: "Oral history with two interview audio segments")}
  let(:cmd) { cmd = TTY::Command.new(printer: :null)}

  context "one viable mp3, characterized during the test" do
    let!(:mp3)  { create(:asset, :inline_promoted_file,
        position: 1,
        parent_id: work.id,
        file: File.open((Rails.root + "spec/test_support/audio/5-seconds-of-silence.mp3"))
      )
    }

    it "recognizes the file has legitimate audio metadata created during test setup", queue_adapter: :inline do
      audio_file = work.members.first.file
      expect(audio_file.metadata['bitrate']).to be_a_kind_of(Integer)
      creator = CombinedAudioDerivativeCreator.new(work)
      expect(creator.audio_metadata_errors).to eq []
    end

    it "creates combined audio derivative", queue_adapter: :inline do
      expect(work.members.map(&:stored?)).to match([true])
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

  context "two viable originals - an mp3 and a flac" do
    let!(:mp3_1)  { create(:asset, :inline_promoted_file,
        position: 1,
        parent_id: work.id,
        file: File.open((Rails.root + "spec/test_support/audio/5-seconds-of-silence.mp3"))
      )
    }
    let!(:flac_2)  { create(:asset, :inline_promoted_file,
        position: 2,
        parent_id: work.id,
        file: File.open((Rails.root + "spec/test_support/audio/5-seconds-of-silence.flac"))
      )
    }


    it "recognizes both files have legitimate audio, created during test setup", queue_adapter: :inline do
      creator = CombinedAudioDerivativeCreator.new(work)
      expect(creator.audio_metadata_errors).to eq []
    end

    it "creates combined audio derivatives", queue_adapter: :inline do
      expect(work.members.map(&:stored?)).to match([true, true])
      expect(work.members.first.file.metadata['bitrate']).to be_a_kind_of(Integer)
      expect(work.members.second.file.metadata['bitrate']).to be_a_kind_of(Integer)

      creator = CombinedAudioDerivativeCreator.new(work)
      expect(creator.audio_metadata_errors).to eq []

      combined_audio_info = creator.generate
      expect(combined_audio_info.start_times.count).to eq 2

      # The lengths should be correct:
      expect(combined_audio_info.start_times).to match([
        [mp3_1.id, 0],
        [flac_2.id, 5.184]
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
      #puts m4a_details

      expect(m4a_details.any?  {|x| x.include? 'duration=10.0'}).to be true

      # Store the fingerprint to ensure that it changes when we swap the two files...
      first_fingerprint = combined_audio_info.fingerprint
      expect(first_fingerprint.class).to eq String
      expect(first_fingerprint.length).to eq 32

      # Now swap the files. This *could* be a separate test, but we want to ensure
      # the fingerprint changes without actually
      # explicitly testing it against a fixed string
      # (which, in turn, could change if we change the recipe).

      expect(work.members.map(&:stored?)).to match([true, true])
      flac_2.position = 1
      mp3_1.position = 2
      mp3_1.save!
      flac_2.save!

      combined_audio_info = CombinedAudioDerivativeCreator.new(work).generate
      expect(combined_audio_info.start_times.count).to eq 2

      expect( combined_audio_info.start_times).to match([
        [flac_2.id, 0],
        [mp3_1.id, 5.0]
      ])

      # Get some verbose details about the files output:

      m4a_details   = cmd.run(*stats_command + [combined_audio_info.m4a_file.path] ).out.split("\n")

      # Are they audio files?
      expect(m4a_details).to  include('codec_tag_string=mp4a')
      expect(m4a_details).to  include('codec_name=aac')
      expect(m4a_details).to  include('format_long_name=QuickTime / MOV')
      expect(m4a_details.any?  {|x| x.include? 'duration=10.0'}).to be true

      second_fingerprint = combined_audio_info.fingerprint
      expect(second_fingerprint.class).to eq String
      expect(second_fingerprint.length).to eq 32
      expect(second_fingerprint).not_to eq first_fingerprint
    end
  end

  context "two broken flacs" do
    # The files don't actually matter too much here, we're just testing missing metadata
    let!(:flac_zero_bytes)  { create(:asset_with_faked_file,
        position: 1,
        parent_id: work.id,
        faked_file: File.open((Rails.root + "spec/test_support/audio/zero_bytes.flac")),
        faked_content_type: "audio/flac"
      )
    }

    let!(:flac_bad_metadata)  { create(:asset_with_faked_file, :flac,
        position: 2,
        parent_id: work.id,
        faked_file: File.open((Rails.root + "spec/test_support/audio/bad_metadata.flac")),
        faked_content_type: "audio/flac",
        faked_duration_seconds: nil,
        faked_bitrate: nil,
        faked_audio_bitrate: nil,
        faked_audio_sample_rate: nil
      )
    }

    it "accurately detects broken files", queue_adapter: :inline do
      expect(work.members.first.file.metadata['bitrate']).to be_nil
      expect(work.members.second.file.metadata['bitrate']).to be_nil

      creator = CombinedAudioDerivativeCreator.new(work)

      expect(creator.audio_metadata_errors).to contain_exactly(
        "zero_bytes.flac: empty file",
        "zero_bytes.flac: audio duration is unavailable or zero",
        "zero_bytes.flac: audio bitrate or sample rate is unavailable",
        "bad_metadata.flac: audio duration is unavailable or zero",
        "bad_metadata.flac: audio bitrate or sample rate is unavailable"
      )
    end

    it "fails quickly", queue_adapter: :inline do
      creator = CombinedAudioDerivativeCreator.new(work)
      combined_audio_info = creator.generate

      expect(creator.available_members_count).to eq 2
      expect(combined_audio_info.errors).to eq(
        "zero_bytes.flac: empty file; zero_bytes.flac: audio duration is unavailable or zero; zero_bytes.flac: audio bitrate or sample rate is unavailable; bad_metadata.flac: audio duration is unavailable or zero; bad_metadata.flac: audio bitrate or sample rate is unavailable"
      )

      expect(combined_audio_info.start_times).to be_nil
      expect(combined_audio_info.m4a_file).to be_nil
      expect(combined_audio_info.fingerprint).to be_nil
    end
  end
end
