# Outputs an <audio> tag that has markup to have video.js actually take it over,
# but in audio-only mode, with custom styling and features we have chosen as
# what we want for our audio player.
#
# Goes with styling from .scihist-video-js-audio-no-poster class in video_js.scss
#
# Content wrapped in the component will be wrapped in the <audio> tag, and should
# normally include one or more <source> tags!
#
# @example
#
#     <%= render AudioPlayerComponent.new do %>
#       <source src="some_path" type="audio/mp4">
#     <% end %>
class AudioPlayerComponent < ApplicationComponent

end
