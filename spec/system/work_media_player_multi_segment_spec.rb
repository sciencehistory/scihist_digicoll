require 'rails_helper'

# Basic happy-path coverage for switching between segments in the "Multiple Segments"
# list on WorkMediaPlayerShowComponent, for both video and audio works. Needs to be
# a system spec because segment-switching is entirely client-side JS (video_player.js),
# nothing to see server-side.
describe "WorkMediaPlayerShowComponent multiple segments", type: :system, js: true do
  # video.js needs a moment after page load (or after switching segments) before
  # the underlying media element's currentSrc reflects the loaded media, so poll
  # for it. We look for `.vjs-tech` (video.js's own class for the actual <video>/
  # <audio> element it creates) rather than "#work-video-player" directly, since
  # video.js renames the id of the original tag it's handed.
  def wait_for_player_src(differs_from: nil)
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop do
        src = page.evaluate_script("document.querySelector('.vjs-tech')?.currentSrc")
        break src if src.present? && src != differs_from
        sleep 0.1
      end
    end
  end

  shared_examples "can switch segments" do
    it "switches the player, now-playing indicator, and transcript when a segment is clicked" do
      visit work_path(work.friendlier_id)

      expect(page).to have_css(".av-transcript-line.av-now-playing", text: "Segment 1")
      initial_src = wait_for_player_src

      click_on "Show transcript"
      expect(page).to have_content("Alpha transcript text")

      click_link "Segment 2"

      expect(page).to have_css(".av-transcript-line.av-now-playing", text: "Segment 2")
      expect(page).to have_no_css(".av-transcript-line.av-now-playing", text: "Segment 1")

      expect(wait_for_player_src(differs_from: initial_src)).not_to eq initial_src

      # transcript swap is an async fetch, Capybara's matcher will wait/retry for it
      expect(page).to have_content("Beta transcript text")
      expect(page).not_to have_content("Alpha transcript text")
    end
  end

  describe "video work" do
    let(:assets) do
      [
        build(:asset_with_faked_file, :video, :asr_vtt, title: "Segment 1", position: 0, published: true, vtt_source: "WEBVTT\n\n00:00.000 --> 00:01.500\nAlpha transcript text"),
        build(:asset_with_faked_file, :video, :asr_vtt, title: "Segment 2", position: 1, published: true, vtt_source: "WEBVTT\n\n00:00.000 --> 00:01.500\nBeta transcript text"),
        build(:asset_with_faked_file, :video, title: "Segment 3", position: 2, published: true),
      ]
    end
    let(:work) { create(:video_work, :published, members: assets) }

    include_examples "can switch segments"
  end

  describe "audio work" do
    let(:assets) do
      [
        build(:asset_with_faked_file, :mp3, :asr_vtt, title: "Segment 1", position: 0, published: true, vtt_source: "WEBVTT\n\n00:00.000 --> 00:01.500\nAlpha transcript text"),
        build(:asset_with_faked_file, :mp3, :asr_vtt, title: "Segment 2", position: 1, published: true, vtt_source: "WEBVTT\n\n00:00.000 --> 00:01.500\nBeta transcript text"),
        build(:asset_with_faked_file, :mp3, title: "Segment 3", position: 2, published: true),
      ]
    end
    let(:work) { create(:work, :published, format: ["sound"], members: assets) }

    include_examples "can switch segments"
  end
end
