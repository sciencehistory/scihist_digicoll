// If page anchor has a timecode in it like #t=13434 where that's a number of seconds, then
// on page load, we should jump to that timecode in audio player.
//
// Using "t" as a key is roughly compatible with WC3 "media fragment" standard, and other
// common practice.
//
// Note this is similar to but different from the play_at_timecode JS that has an on-screen element that
// can be clicked to advance to timecode, without changing the #fragmentIdentifier.

import domready from 'domready';
import {gotoTocSegmentAtTimecode, getActiveTab} from './helpers/ohms_player_helpers.js';

domready(function() {
  var hashParams = new URLSearchParams(window.location.hash.replace(/^#/, ''));
  var timeCodeSeconds = window.location.hash.includes("=") && hashParams.get("t");

  if (timeCodeSeconds) {
    var player = document.querySelector("*[data-role=now-playing-container] audio");
    if (player) {

      // player might not be in state where it can seek yet, if not then wait.
      if (player.readyState >=  player.HAVE_METADATA) {
        setupTimeSeek(player, timeCodeSeconds);
      } else {
        player.addEventListener("loadedmetadata", function(event) {
          setupTimeSeek(player, timeCodeSeconds);
        });
      }

      // goto relevant toc segment if requested
      if (hashParams.get("tab") == "ohToc") {

        if (getActiveTab().id == "ohTocTab") {
          gotoTocSegmentAtTimecode(timeCodeSeconds);
        } else {
          // not shown yet, other code will async make it shown, we have
          // to say once it's shown, open and scroll  to toc segment.
          jQuery('*[data-toggle="tab"][href="#ohToc"]').one('shown.bs.tab', function(event) {
            gotoTocSegmentAtTimecode(timeCodeSeconds);
          });
        }
      }
    }
  }
});

// Must be called when player is in a readyState where we can seek,
// at least HAVE_METADATA. https://developer.mozilla.org/en-US/docs/Web/API/HTMLMediaElement/readyState
function setupTimeSeek(player, timeCodeSeconds) {
  player.currentTime = timeCodeSeconds;

  startPlaying(player);
}

// Now we want to play on page load (we think?), but Modern browsers don't let us play
// before user has interacted with document. if we catch the error, we will sneakily
// start playing as soon as they click anywhere. We are not trying to annoy
// them, but think this may be what they want, needs more investigation.
function startPlaying(player) {
  var playPromise  = player.play();
  if (playPromise !== undefined) {
    playPromise.catch(error => {
      // Autoplay was prevented, let's start plaing on any click.
      document.addEventListener("click",
        function(event) {
          player.play();
        },
        { once: true} // only execute once.
      );
    });
  }
}

