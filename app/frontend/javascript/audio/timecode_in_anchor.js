// If page anchor has a timecode in it like #t=13434 where that's a number of seconds, then
// on page load, we should jump to that timecode in audio player.
//
// Using "t" as a key is roughly compatible with WC3 "media fragment" standard, and other
// common practice.
//
// Note this is similar to but different from the play_at_timecode JS that has an on-screen element that
// can be clicked to advance to timecode, without changing the #fragmentIdentifier.

import domready from 'domready';
import {gotoTocSegmentAtTimecode, gotoTranscriptTimecode} from './helpers/ohms_player_helpers.js';

domready(function() {
  var hashParams = new URLSearchParams(window.location.hash.replace(/^#/, ''));
  var timeCodeSeconds = window.location.hash.includes("=") && hashParams.get("t");

  if (timeCodeSeconds) {
    if (history.scrollRestoration) {
      history.scrollRestoration = 'manual';
    }

    var player = document.querySelector("*[data-role=now-playing-container] audio");
    if (player) {

      // player might not be in state where it can seek yet, if not then wait
      // and seek when we can.
      if (player.readyState >=  player.HAVE_METADATA) {
        setupTimeSeek(player, timeCodeSeconds);
      } else {
        player.addEventListener("loadedmetadata", function(event) {
          setupTimeSeek(player, timeCodeSeconds);
        });
      }

      // "tab" in anchor will cause other JS code in another file to switch to that tab.
      //
      // If tab in anchor is ToC, we expand to relevant segment.
      //
      // Otherwise, we need to switch to transcript tab and jump to relevant timecode.

      if (hashParams.get("tab") == "ohToc") {
        execWhenTabActive("ohToc", function() {
          gotoTocSegmentAtTimecode(timeCodeSeconds);
        });
      } else {
        if (hashParams.get("tab") != "ohTranscript") {
          $(`*[data-bs-toggle="tab"][href="#ohTranscript"]`).tab("show");
        }
        execWhenTabActive("ohTranscript", function() {
          gotoTranscriptTimecode(timeCodeSeconds);
        });
      }
    }
  }
});

// Something has already executed bootstrap tab to switch to targetTabId. But maybe
// it's finished it's transition, maybe it hasn't. We want to execute procArg
// only once/if transition to tab is complete.
function execWhenTabActive(targetTabId, procArg) {
  var activeTabContentId = document.querySelector("#ohmsScrollable .tab-pane.active")?.id;

  if (activeTabContentId == targetTabId) {
    procArg();
  } else {
    // not shown yet, other code will async make it shown, we have
    // to say once it's shown, open and scroll  to toc segment.
    jQuery(`*[data-bs-toggle="tab"][href="#${targetTabId}"]`).one('shown.bs.tab', function(event) {
      procArg();
    });
  }
}

// Must be called when player is in a readyState where we can seek,
// at least HAVE_METADATA. https://developer.mozilla.org/en-US/docs/Web/API/HTMLMediaElement/readyState
function setupTimeSeek(player, timeCodeSeconds) {
  player.currentTime = timeCodeSeconds;

  var playPromise  = player.play();

  if (playPromise !== undefined) {
    playPromise.catch(error => {
      console.log(`could not autoplay: ${error}`);
    });
  }
}

