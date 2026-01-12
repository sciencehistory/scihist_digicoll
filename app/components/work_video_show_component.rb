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
  delegate :construct_page_title, :can_see_unpublished_records?, to: :helpers
  attr_reader :work

  def initialize(work)
    @work = work
  end

  def poster_src
    @work.leaf_representative&.file_derivatives(:thumb_large)&.url || video_asset.file_derivatives(:thumb_large)&.url || asset_path("placeholderbox.svg")
  end

  def video_src_url
    video_asset.file_url(expires_in: 5.days.to_i)
  end

  def auto_caption_track_url
    unless defined? @auto_caption_track_url
      @auto_caption_track_url = if video_asset.corrected_webvtt?
        download_derivative_path(video_asset, Asset::CORRECTED_WEBVTT_DERIVATIVE_KEY, disposition: :inline)
      elsif video_asset&.audio_asr_enabled? && video_asset.asr_webvtt?
        download_derivative_path(video_asset, Asset::ASR_WEBVTT_DERIVATIVE_KEY, disposition: :inline)
      end
    end

    @auto_caption_track_url
  end

  def has_vtt_transcript?
    (video_asset&.audio_asr_enabled? && video_asset&.asr_webvtt?) || video_asset&.corrected_webvtt?
  end

  def vtt_transcript_str
    if video_asset.corrected_webvtt?
      video_asset.corrected_webvtt_str
    elsif video_asset.asr_webvtt?
      video_asset.asr_webvtt_str
    end
  end

  # the first video member we find. otherwise nil.
  def video_asset
    candidate = @work.members.find { |w| w&.content_type&.start_with?("video/") }
    candidate if (candidate.published? || can_see_unpublished_records?)
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
