import videojs from 'video.js';
import { seekAndAutoPlayWhenReady } from './media_seek.js';

// css is imported through our CSS pipelines, with custom theming, in video_js.scss

// id of the <track> element we render for our own ASR/corrected captions. Must
// match id in initial track rendered in ERB.
const AUTO_CAPTION_TRACK_ID = "scihistAutoCaptions";

// css class marking the transcript line matching current playback position
const highlightCssClass = "transcript-highlighted";

const videoPlayerEl = document.querySelector("#work-video-player");

if (videoPlayerEl) {
  setupVideoPlayer(videojs(videoPlayerEl));
}

// Wiring registered ONCE for the life of the page. Media loaded in player
// may change, don't assume it will remain what was there at load.
//
function setupVideoPlayer(player) {
  const textTracks = player.textTracks();

  // Safari adds empty captions that we have to remove
  if (navigator.vendor?.includes("Apple")) {
    textTracks.addEventListener("addtrack", function() {
      removeEmptySafariTextTracks(player);
    });
  }

  // For custom skin/theme, we want to underline when captions are showing.
  //
  // We listen for tracks coming and going as well as for "change", so the button
  // is still correct after a change of media -- "change" alone does not fire when
  // tracks simply go away with the old source.
  ["change", "addtrack", "removetrack"].forEach(function(eventName) {
    textTracks.addEventListener(eventName, function() {
      updateCaptionsButtonState(player);
    });
  });

  // When a caption track is loaded -- either initial page load, or when
  // switching media segments -- we need to set it up for transcript syncing.
  textTracks.addEventListener("addtrack", function(event) {
    if (event.track.id === AUTO_CAPTION_TRACK_ID) {
      setupAutoCaptionTrack(player, event.track);
    }
  });

  // Shouldn't be needed, but just in case our listener was added too late somehow,
  // we've written idempotently.
  setupAutoCaptionTrack(player, textTracks.getTrackById(AUTO_CAPTION_TRACK_ID));

  // When user disables captions, our caption tracks are set to 'disabled' again--
  // but we need them as 'hidden' because we use them for transcript syncing
  // even when not visible.
  textTracks.addEventListener("change", function() {
    const track = player.textTracks().getTrackById(AUTO_CAPTION_TRACK_ID);

    if (track && track.mode == "disabled") {
      track.mode = "hidden";
    }
  });

  // When transcript window opens, scroll to current highlight if needed.
  const transcriptCollapsible = document.getElementById('show-video-transcript-collapse');
  transcriptCollapsible?.addEventListener('shown.bs.collapse', event => {
    let highlighted = document.querySelector(`.${highlightCssClass}`);
    if (highlighted && !elementFullyVisibleWithin(highlighted, transcriptCollapsible)) {
      scrollToTranscriptHighlight(highlighted);
    }
  });

  // Multi-segment works list their video segments below the player. Clicking one
  // loads that video (and its caption track) into the existing player, from
  // JSON serialized info on the link.
  //
  document.querySelector(".av-transcript-list")?.addEventListener("click", function(event) {
    const segmentLink = event.target.closest("[data-av-media]");
    if (!segmentLink) {
      return;
    }

    event.preventDefault();
    loadMediaForLink(player, segmentLink);
  });

  // On initial load, link anchor may include a specific segment to load
  // (`a=friendlier_id`) and/or a specific timecode to seek to (in that segment)
  player.ready(function() {
    loadMediaFromAnchor(player);
  });
}


// Switch to segment named in anchor if needed and/or seek to timecode named
function loadMediaFromAnchor(player) {
  const hashParams = new URLSearchParams(window.location.hash.replace(/^#/, ""));
  const assetId = hashParams.get("a");
  const timeCodeSeconds = hashParams.get("t");

  let switching = false;

  if (assetId) {
    // CSS.escape since assetId comes straight from the URL fragment
    const segmentLink = document.querySelector(`a[data-friendlier-id="${CSS.escape(assetId)}"]`);

    // already the loaded segment, nothing to switch
    const alreadyLoaded = segmentLink?.closest(".av-transcript-line")?.classList?.contains("av-now-playing");

    if (segmentLink && !alreadyLoaded) {
      switching = true;

      // If we want to see after, we have to make sure to do it AFTER the new
      // media is loaded, so we don't seek on old media first!
      if (timeCodeSeconds) {
        player.one("loadstart", function() {
          seekAndAutoPlayWhenReady(player, timeCodeSeconds);
        });
      }

      loadMediaForLink(player, segmentLink);
    }
  }

  // If we didn't switch media first, now we can seek in a normal way.
  if (timeCodeSeconds && !switching) {
    seekAndAutoPlayWhenReady(player, timeCodeSeconds);
  }
}


// Load the segment a segment link points to into the player, from serialized
// data on the link (see WorkVideoShowComponent#av_media_for), and reflect it
// as now playing.
function loadMediaForLink(player, segmentLink) {
  const mediaData = JSON.parse(segmentLink.dataset.avMedia);

  const media = {
    src: { src: mediaData.video_url, type: mediaData.video_type },
    poster: mediaData.poster_url
  };

  if (mediaData.captions_url) {
    media.textTracks = [{
      id: AUTO_CAPTION_TRACK_ID,
      src: mediaData.captions_url,
      kind: "captions",
      label: "Auto-captions"
    }];
  }

  player.loadMedia(media);

  markSegmentNowPlaying(segmentLink, mediaData);
}

// Reflect the segment just loaded: move the "now playing" highlight to its row,
// and update the "now playing" line under the player with its title and position.
function markSegmentNowPlaying(segmentLink, avMedia) {
  const list = segmentLink.closest(".av-transcript-list");

  // highlight correct row
  list.querySelectorAll(".av-now-playing").forEach(function(el) {
    el.classList.remove("av-now-playing");
  });
  segmentLink.closest(".av-transcript-line")?.classList.add("av-now-playing");

  // Add now playing title and position to bar under player
  const label = document.querySelector(".av-now-playing-label");
  if (label) {
    label.querySelector(".av-now-playing-title").textContent = avMedia.title;
    label.querySelector(".av-now-playing-position").textContent = `${avMedia.position} / ${avMedia.total}`;
  }
}


function setupAutoCaptionTrack(player, track) {
  if (!track) {
    return;
  }

  // hidden rather than disabled, so we get cuechange events for transcript syncing
  // even when the user has captions turned off.
  if (track.mode == "disabled") {
    track.mode = "hidden";
  }

  setupTranscriptHighlighting(player, track);
}


// Look for extra empty caption tracks safari loads from HLS manifests that do
// not declare no captions, and remove them.
//
// See:
//   * https://github.com/videojs/video.js/issues/2808
//   * https://developer.apple.com/library/archive/qa/qa1801/_index.html
//
// And in ramp project (not sure why they aren't doing it on desktop Safari, we
// do need it there):
//   * https://github.com/samvera-labs/ramp/blob/23aae5c5aa9e7c95d1c94cba5cf870daf76df1aa/src/components/MediaPlayer/VideoJS/VideoJSPlayer.js#L571-L597
function removeEmptySafariTextTracks(player) {
  const textTracks = player.textTracks();

  for (let i = 0; i < textTracks.length; i++) {
    // empty language and label are ones safari adds for HLS manifest without
    // CLOSED_CAPTION=none, we don't want em.
    if (textTracks[i].language === '' && textTracks[i].label === '') {
      textTracks.removeTrack(textTracks[i]);
    }
  }
}

// Add a class to the "CC" captions button to add the underline when
// captions are visible.
function updateCaptionsButtonState(player) {
  // Odd JS way to turn it to a standard array so we can iterate
  const trackArr = Array.prototype.slice.call(player.textTracks(), 0);
  const button = document.querySelector("button.vjs-subs-caps-button");

  if (trackArr.find( track => track.mode == "showing")) {
    button?.classList?.add("text-track-visible");
  } else {
    button?.classList?.remove("text-track-visible");
  }
}


// in on-page transcript, highlight current line that matches where video is playing,
// scrolling to it if necessary. A lot of this UX is modelled on youtube
//
// We count on the fact that we have our VTT loaded in the video as a text track, so
// we can use HTML5 video API to find "activeCues" at any given time, and then locate those
// in the transcript. Using HTML5 video API via video.js, which delegates or polyfills as needed.
//
function setupTranscriptHighlighting(player, captionsTrack) {
  // whether captionsTrack is visible or hidden, we'll get cuechange
  // events we can use to highlight our transcript
  captionsTrack.addEventListener("cuechange", function() {
    // remove transcript highlights
    document.querySelectorAll(`.${highlightCssClass}`).forEach( (el) => el.classList.remove(highlightCssClass));

    // Now highlight in transcript for current cue, if available.
    const highlightedEl = addTranscriptHighlights(player, captionsTrack.activeCues);

    // Scroll to highlighted El if present, the transcript is open, and the
    // mouse cursor isn't currently over transcript window. UX modelled on Youtube.
    if (highlightedEl &&
        document.querySelector("#show-video-transcript-collapse.show") &&
        !document.querySelector("*[data-transcript-content-target]").matches(':hover')) {
      scrollToTranscriptHighlight(highlightedEl);
    }
  });
}


// add css class to highlight transcript lines for current active cues from
// caption track.
function addTranscriptHighlights(player, activeCues) {
  if (!activeCues || activeCues.length == 0) {
    return;
  }

  // Odd JS way to turn it to a standard array so we can interate
  let activeCuesArr = Array.prototype.slice.call(activeCues, 0)

  // Sometimes there's more than one because end time for one cue is start time for the other,
  // we dont' need to show the one that's about to end.
  if (activeCuesArr.length > 1) {
    activeCuesArr = activeCuesArr.filter( cue => player.currentTime() <= (cue.endTime - 0.25) );
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
  if (!elementFullyVisibleWithin(line, container)) {
    container.scrollTo(0, line.offsetTop);
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
