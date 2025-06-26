require 'rails_helper'

describe WorkVideoShowComponent, type: :component do
  let(:work) { create(:video_work, :published) }
  let(:placeholder_img_src) { ActionController::Base.helpers.asset_path("placeholderbox.svg") }

  it "has video element properly set up" do
    render_inline described_class.new(work)

    video_element = page.first("video")

    expect(video_element).to be_present
    expect(video_element["poster"]).to eq work.representative.file_derivatives[:thumb_large].url

    source_element = video_element.find("source")

    expect(source_element["src"]).to eq work.representative.file_url
    expect(source_element["type"]).to eq work.representative.content_type

    expect(source_element).not_to have_selector("track")
  end

  describe "when it is missing derivatives" do
    before do
      work.representative.remove_derivatives(*work.representative.file_derivatives.keys)
      expect(work.representative.file_derivatives).to be_empty
    end

    it "can still display page without errors" do
      render_inline described_class.new(work)
      expect(page.first("video")).to be_present
    end
  end

  describe "when we have an HLS URL" do
    # Work with an hls url that doesn't actually point anywhere, but fine,
    # we just set it to point to a non-existent thing using shrine
    # internals.
    let(:work) do
      create(:video_work, :published).tap do |work|
        work.representative.hls_playlist_file_attacher.set(
          VideoHlsUploader.uploaded_file(
            storage: "video_derivatives",
            id: "some_path/hls.m3uh"
          )
        )
        work.representative.save!
      end
    end

    it "outputs HLS url in video tag" do
      render_inline described_class.new(work)

      video_element = page.first("video")
      first_source_element = video_element.first("source")

      expect(first_source_element).to be_present
      expect(first_source_element["type"]).to eq("application/x-mpegURL")
      expect(first_source_element["src"]).to eq(work.representative.hls_playlist_file.url(public: true))
    end
  end

  describe "when representative is private but visible to staff", logged_in_user: true do
    let(:work) do
      create(:video_work, :published).tap do |work|
        work.representative.update(published: false)
      end
    end

    it "includes video and private tag" do
      render_inline described_class.new(work)

      expect(page).to have_selector("video")
      expect(page).to have_selector(".show-video", text: /Private/)
    end

  end

  describe "when representative is not visible to non-logged-in user" do
    let(:work) do
      create(:video_work, :published).tap do |work|
        work.representative.update(published: false)
      end
    end

    it "includes placeholder only" do
      render_inline described_class.new(work)

      expect(page).not_to have_selector("video")
      expect(page).to have_selector("img[src='#{placeholder_img_src}']")
    end
  end

  describe "with captions" do
    let(:work) { create(:video_work, :published, members: [ asset ]) }

    describe "only ASR captions" do
      let(:asset) { build(:asset_with_faked_file, :video, :asr_vtt) }


      it "includes track element" do
        render_inline described_class.new(work)

        expect(page).to have_selector("video track", count: 1)
        track_element = page.first("video track")

        expect(track_element["src"]).to eq download_derivative_path(asset, Asset::ASR_WEBVTT_DERIVATIVE_KEY, disposition: :inline)
        expect(track_element["label"]).to eq "Auto-captions"
        expect(track_element["kind"]).to eq "captions"
        expect(track_element["id"]).to eq "scihistAutoCaptions" # used by JS
      end

      it "includes on-page transcript toggle" do
        render_inline described_class.new(work)

        expect(page).to have_selector("#showVideoTranscriptToggle[data-bs-target='#show-video-transcript-collapse']", text: /Show transcript/i)
        expect(page).to have_selector("#show-video-transcript-collapse.collapse")
      end
    end

    describe "only ASR captions but without audio_asr_enabled" do
      let(:asset) { build(:asset_with_faked_file, :video, :asr_vtt, audio_asr_enabled: false) }

      it "does not show captions" do
        render_inline described_class.new(work)

        expect(page).not_to have_selector("video track", count: 1)

        expect(page).not_to have_selector(:link_or_button, text: /Show transcript/i)
        expect(page).not_to have_selector("#show-video-transcript-collapse.collapse")
      end
    end

    describe "corrected captions" do
      let(:asset) { build(:asset_with_faked_file, :video, :corrected_vtt) }

      it "includes track element for corrected" do
        instance = described_class.new(work)
        render_inline instance

        expect(instance.vtt_transcript_str).to eq asset.corrected_webvtt_str

        expect(page).to have_selector("video track", count: 1)
        track_element = page.first("video track")

        expect(track_element["src"]).to eq download_derivative_path(asset, Asset::CORRECTED_WEBVTT_DERIVATIVE_KEY, disposition: :inline)
        expect(track_element["label"]).to eq "Auto-captions"
        expect(track_element["kind"]).to eq "captions"
      end
    end
  end

end

