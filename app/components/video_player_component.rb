# Outputs an <video> tag that has markup for video.js to take it over, with
# our preferred styling and configuration.
#
# Goes with styling from .scihist-video-js-audio-no-poster class in video_js.scss
#
# Content wrapped in the component will be wrapped in the <audio> tag, and should
# normally include one or more <source> tags!
#
# @example
#
#     <%= render VideoPlayerComponent.new(aspect_ratio: "16:9") do %>
#       <source src="some_path" type="video/mp4">
#     <% end %>
#
class VideoPlayerComponent < ApplicationComponent
  attr_reader :aspect_ratio, :poster_src_url

  # @param aspect_ratio [String] eg "16:9", required param but you can send in
  #   nil and no aspect ratio will be sent to video-js, which may have unpredictable
  #   display
  #
  # @param poster_src_url [String] required but can be nil if no poster image
  def initialize(aspect_ratio:,poster_src_url:)
    @aspect_ratio = aspect_ratio
    @poster_src_url = poster_src_url
  end
end
