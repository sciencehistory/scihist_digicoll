import videojs from 'video.js';

// css is imported through our CSS pipelines, with custom theming, in video_js.scss

const videoPlayerEl = document.querySelector("#work-video-player")

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
if (videoPlayerEl && navigator.vendor?.includes("Apple")) {
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


// in on-page transcript, highlight current line that matches where video is playing,
// scrolling to it if necessary. A lot of this UX is modelled on youtube
//
// We count on the fact that we have our VTT loaded in the video as a text track, so
// we can use HTML5 video API to find "activeCues" at any given time, and then locate those
// in the transcript. Using HTML5 video API via video.js, which delegates or polyfills as needed.
if (videoPlayerEl) {
  const highlightCssClass = "transcript-highlighted"

  videojs(videoPlayerEl).ready(function() {
    const autoCaptionTrack = this.textTracks().getTrackById("scihistAutoCaptions");
    if (autoCaptionTrack) {
      let currentCues = null;

      this.on("timeupdate", function() {
        const stringified = JSON.stringify(autoCaptionTrack.activeCues);

        if (currentCues != stringified) {
          removeTranscriptHighlights();
          addTranscriptHighlights(autoCaptionTrack.activeCues);


          currentCues = stringified;
        }
      });
    }

    function removeTranscriptHighlights() {
      document.querySelectorAll(`.${highlightCssClass}`).forEach( (el) => el.classList.remove(highlightCssClass))
    }

    function addTranscriptHighlights(activeCues) {
      // Odd JS way to turn it to a standard array so we can interate
      const activeCuesArr = Array.prototype.slice.call(activeCues, 0)

      activeCuesArr.forEach( (cue) => {
        // in HTML attribute, we rounded to one digit after decimal point... hope it's the same
        // rounding algorithm? TODO we need to test, or change algorithm.
        document.querySelectorAll(`*[data-ohms-timestamp-s="${cue.startTime.toFixed(1)}"]`).forEach( (el) => {
          el.closest(".ohms-transcript-paragraph-wrapper")?.classList?.add(highlightCssClass);
        });
      })
    }
  });
}



