import videojs from 'video.js';

// if we have a video player, look for extra track empty captions safari loads
// from HLS manifests that do not declare no captions, and remove them.
//
// See:
//   * https://github.com/videojs/video.js/issues/2808
//   * https://developer.apple.com/library/archive/qa/qa1801/_index.html
//
// And in ramp project (not sure why they aren't doing it on desktop Safari, we
// do need it there):
//   * https://github.com/samvera-labs/ramp/blob/23aae5c5aa9e7c95d1c94cba5cf870daf76df1aa/src/components/MediaPlayer/VideoJS/VideoJSPlayer.js#L571-L597
if (navigator.vendor?.includes("Apple")) {
  const videoPlayerEl = document.querySelector("#work-video-player")
  if (videoPlayerEl) {
    const textTracks = videojs(videoPlayerEl).textTracks();

    textTracks.on('addtrack', function() {
      for (let i = 0; i < textTracks.length; i++) {
        // empty language and label are ones safari adds for HLS manifest without CLOSED_CAPTION=none,
        // we don't want em.
        if (textTracks[i].language === '' && textTracks[i].label === '') {
          textTracks.removeTrack(textTracks[i]);
        }
      }
    });
  }
}

// css is imported through our CSS pipelines, with custom theming, in video_js.scss

