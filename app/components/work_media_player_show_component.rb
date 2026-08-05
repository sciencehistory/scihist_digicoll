# Individual work detail/show/view page for AUDIO and VIDEO
#
# Can dispaly audio or video, including works with multiples of either. Is not
# designed for mixed audio/vidoe content, would need to attend to that if needed.
#
# If the work has any non-av members, they may not show up on display page... can be enhanced
# if we have a use case.
#
# This is similar layout to standard WorkImageShowComponent, but replaces poster
# thumb with a player, and also allows a list of selectable multiple segments. We make it a
# separate component copying some template instead of trying to DRY somehow, thinking it
# will wind up less convoluted this way for now.
class WorkMediaPlayerShowComponent < ApplicationComponent
  delegate :construct_page_title, :can_see_unpublished_records?, :format_ohms_timestamp, :current_user,
    to: :helpers

  attr_reader :work

  def initialize(work)
    @work = work
  end

  # choose and instantiate a component to display either video or audio player,
  # depending on content.
  #
  # Both players are actually video.js, just set up differently. Both our video
  # and audio components take a render block with contents, usually <source> tags
  def media_player_component_instance
    if use_video_player?
      VideoPlayerComponent.new(aspect_ratio: initial_media_asset_aspect_ratio, poster_src_url: poster_src_url)
    else
      AudioPlayerComponent.new
    end
  end

  # If ANY asset is video, use video player (which can also play audio, just with non-ideal UX)
  # We aren't really set up for mixed audio/video content right now, but this will kind of work.
  def use_video_player?
    (media_assets.any? { |a| a.content_type&.start_with?("video/") })
  end

  def poster_src_url
    @work.leaf_representative&.file_derivatives(:thumb_large)&.url || initial_media_asset.file_derivatives(:thumb_large)&.url || asset_path("placeholderbox.svg")
  end

  def asset_src_url(asset)
    asset.file_url(expires_in: 5.days.to_i)
  end

  def auto_caption_track_url(media_asset)
    if media_asset.corrected_webvtt?
      download_derivative_path(media_asset, Asset::CORRECTED_WEBVTT_DERIVATIVE_KEY, disposition: :inline)
    elsif media_asset&.audio_asr_enabled? && media_asset.asr_webvtt?
      download_derivative_path(media_asset, Asset::ASR_WEBVTT_DERIVATIVE_KEY, disposition: :inline)
    end
  end

  # will be used in `data-av-media` attribute: what JS needs to load a segment
  # into the player
  def av_media_for(asset)
    {
      video_url:    asset.hls_playlist_file&.url || asset_src_url(asset),
      video_type:   asset.hls_playlist_file.present? ? "application/x-mpegURL" : asset.content_type,
      poster_url:   asset.file_derivatives(:thumb_large)&.url,
      captions_url: auto_caption_track_url(asset),
      width:        asset.width,
      height:       asset.height,
      transcript_fragment_url: (asset_transcript_path(asset, fragment: true) if asset.has_webvtt?)
    }
  end

  def has_any_transcript?
    !! media_assets.find do |asset|
      (asset&.audio_asr_enabled? && asset&.asr_webvtt?) || asset&.corrected_webvtt?
    end
  end

  def initial_vtt_transcript_str
    if initial_media_asset.corrected_webvtt?
      initial_media_asset.corrected_webvtt_str
    elsif initial_media_asset.asr_webvtt?
      initial_media_asset.asr_webvtt_str
    end
  end


  def media_assets
    @media_assets ||= begin
      scope = @work.members.order(:position)

      unless AccessPolicy.new(current_user).can_see_unpublished_records?
        scope = scope.where(published: true)
      end

      scope.find_all do |mem|
        mem.asset? &&
        (mem&.content_type&.start_with?("video/") || mem&.content_type&.start_with?("audio/"))
      end
    end
  end

  def initial_media_asset
    @initial_media_asset = media_assets.first
  end

  def initial_media_asset_aspect_ratio
    if initial_media_asset && initial_media_asset.width && initial_media_asset.height
      "#{ initial_media_asset.width }:#{ initial_media_asset.height }"
    end
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
