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

      //We need text track to be hidden instead of disabled, so we can still track
      //cuechange events for transcript
      autoCaptionTrack.mode = "hidden";
      this.textTracks().addEventListener("change", function() {
        if (autoCaptionTrack.mode == "disabled") {
          autoCaptionTrack.mode = "hidden";
        }
      });

      // whether track is visible or hidden, we'll get cuechange
      // events we can use to highlight our transcript
      autoCaptionTrack.addEventListener("cuechange", function() {
        removeTranscriptHighlights();

        const highlightedEl = addTranscriptHighlights(autoCaptionTrack.activeCues);

        // Scroll to highlighted El if present, the transcript is open, and the
        // mouse cursor isn't currently over transcript window. UX modelled on Youtube.
        if (highlightedEl &&
            document.querySelector("#show-video-transcript-collapse.show") &&
            !document.querySelector("*[data-transcript-content-target]").matches(':hover')) {
          scrollToTranscriptHighlight(highlightedEl);
        }
      });

      // When transcript window opens, scroll to if needed
      const transcriptCollapsible = document.getElementById('show-video-transcript-collapse');
      transcriptCollapsible.addEventListener('shown.bs.collapse', event => {
        let highlighted = document.querySelector(`.${highlightCssClass}`);
        if (highlighted && !elementFullyVisibleWithin(highlighted, transcriptCollapsible)) {
          scrollToTranscriptHighlight(highlighted);
        }
      })
    }

    const vjsPlayer = this;

    function removeTranscriptHighlights() {
      document.querySelectorAll(`.${highlightCssClass}`).forEach( (el) => el.classList.remove(highlightCssClass))
    }

    function addTranscriptHighlights(activeCues) {
      if (!activeCues || activeCues.length == 0) {
        return;
      }

      // Odd JS way to turn it to a standard array so we can interate
      let activeCuesArr = Array.prototype.slice.call(activeCues, 0)

      // Sometimes there's more than one because end time for one cue is start time for the other,
      // we dont' need to show the one that's about to end.
      if (activeCuesArr.length > 1) {
        activeCuesArr = activeCuesArr.filter( cue => {
          vjsPlayer.currentTime() <= (cue.endTime - 0.25)
        });
      }

      let firstHighlightedEl = undefined;

      activeCuesArr.forEach( (cue) => {
        // when outputting seconds float in vtt_transcript_component.html.erb, it must be output
        // with exact same number of decimal places including trailing zeroes as here.
        document.querySelectorAll(`*[data-ohms-timestamp-s="${cue.startTime.toFixed(3)}"]`).forEach( (el) => {
          firstHighlightedEl = firstHighlightedEl || el;

          el.closest(".ohms-transcript-paragraph-wrapper")?.classList?.add(highlightCssClass);
        });
      });

      // Return first one to scroll to
      return firstHighlightedEl;
    }

    function scrollToTranscriptHighlight(highlightedEl) {
      const container = document.querySelector("*[data-transcript-content-target]");
      const line = highlightedEl.closest('.ohms-transcript-paragraph-wrapper');

      // Do nothing if it's already scrolled *entirely* in container view
      if (elementFullyVisibleWithin(line, container)) {
        return false;
      }

      // otherwise continue, do two lines before if possible, matching youtube UX
      let scrollToEl = line.previousElementSibling || line;
      //scrollToEl = scrollToEl.previousElementSibling || scrollToEl;

      container.scrollTo(0, scrollToEl.offsetTop);

      // on small screen with really big lines, maybe it's still not visible,
      // we need to skip the previous line and just put this on top
      if (!elementFullyVisibleWithin(line, constainer)) {
        conatainer.scrollTo(0, line.offsetTop);
      }
    }

    function elementFullyVisibleWithin(element, container) {
      const elementRect = element.getBoundingClientRect();
      const containerRect = container.getBoundingClientRect();

      return (elementRect.bottom >= containerRect.top &&
              elementRect.bottom <= containerRect.bottom &&
              elementRect.top <= containerRect.bottom &&
              elementRect.top >= containerRect.top);

    }
  });
}



