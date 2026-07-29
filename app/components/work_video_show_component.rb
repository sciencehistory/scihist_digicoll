# Individual work detail/show/view page for VIDEO
#
# Initially designed for a SINGLE video, which is the work #representative.
#
# If the work has any other members, they may not show up on display page... starting
# with the simple use case.
#
# This is very similar in some wyas to standard WorkImageShowComponent, but we make
# it a separate class instead of trying to use lots of conditionals in one class, betting
# that will be simpler overall, and allow them to diverge as more features are added.
class WorkVideoShowComponent < ApplicationComponent
  delegate :construct_page_title, :can_see_unpublished_records?, :format_ohms_timestamp,
    to: :helpers

  attr_reader :work

  def initialize(work)
    @work = work
  end

  def poster_src
    @work.leaf_representative&.file_derivatives(:thumb_large)&.url || initial_video_asset.file_derivatives(:thumb_large)&.url || asset_path("placeholderbox.svg")
  end

  def video_src_url(asset)
    asset.file_url(expires_in: 5.days.to_i)
  end

  def auto_caption_track_url(video_asset)
    if video_asset.corrected_webvtt?
      download_derivative_path(video_asset, Asset::CORRECTED_WEBVTT_DERIVATIVE_KEY, disposition: :inline)
    elsif video_asset&.audio_asr_enabled? && video_asset.asr_webvtt?
      download_derivative_path(video_asset, Asset::ASR_WEBVTT_DERIVATIVE_KEY, disposition: :inline)
    end
  end

  # will be used in `data-av-media` attribute: what JS needs to load a segment
  # into the player
  def av_media_for(asset)
    {
      video_url:    asset.hls_playlist_file&.url || video_src_url(asset),
      video_type:   asset.hls_playlist_file.present? ? "application/x-mpegURL" : asset.content_type,
      poster_url:   asset.file_derivatives(:thumb_large)&.url,
      captions_url: auto_caption_track_url(asset),
      width:        asset.width,
      height:       asset.height,
      transcript_fragment_url: (asset_transcript_path(asset, fragment: true) if asset.has_webvtt?)
    }
  end

  def has_vtt_transcript?
    (initial_video_asset&.audio_asr_enabled? && initial_video_asset&.asr_webvtt?) || initial_video_asset&.corrected_webvtt?
  end

  def initial_vtt_transcript_str
    if initial_video_asset.corrected_webvtt?
      initial_video_asset.corrected_webvtt_str
    elsif initial_video_asset.asr_webvtt?
      initial_video_asset.asr_webvtt_str
    end
  end

  def video_assets
    @video_assets ||= @work.members.order(:position).find_all do |mem|
      mem.asset? &&
      mem&.content_type&.start_with?("video/") &&
      (mem.published? || can_see_unpublished_records?)
    end
  end

  def initial_video_asset
    @initial_video_asset = video_assets.first
  end

  def private_label
    content_tag(:div, class: "private-badge-div") do
      content_tag(:span, title: "Private", class: "badge text-bg-warning") do
        '<i class="fa fa-exclamation-triangle" aria-hidden="true"></i>'.html_safe +
          " Private"
      end
    end
  end
end
