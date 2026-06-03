// If page anchor has a timecode in it like #t=13434 where that's a number of seconds, then
// on page load, we should jump to that timecode in audio or video player.
//
// Used for both Oral History audio, and work show video.
//
// Confusingly, now also used for #p={paragraph number} anchor linking in oral histories.
//
// Using "t" as a key is roughly compatible with WC3 "media fragment" standard, and other
// common practice.
//
// Note this is similar to but different from the play_at_timecode JS that has an on-screen element that
// can be clicked to advance to timecode, without changing the #fragmentIdentifier.

import domready from 'domready';
import {gotoTocSegmentAtTimecode, gotoTranscriptTimecode, scrollToElement} from './helpers/ohms_player_helpers.js';
import * as bootstrap from 'bootstrap';
import videojs from 'video.js';

domready(function() {
  var hashParams = new URLSearchParams(window.location.hash.replace(/^#/, ''));
  var timeCodeSeconds = window.location.hash.includes("=") && hashParams.get("t");
  var paragraphNumber = window.location.hash.includes("=") && hashParams.get("p");


  if (timeCodeSeconds) {
    if (history.scrollRestoration) {
      history.scrollRestoration = 'manual';
    }

    var playerDomEl = document.querySelector("*[data-role=now-playing-container] audio, .video-player video");

    // Another file should actually be creating the videoJSPlayer obj we need, wait for it if needed.
    onVideoJSSetupFor(playerDomEl, function(videoJsPlayer) {

      // Try to seek and then auto-play. player might not be in state where it can
      // seek yet, if it is not then try to wait and seek when we can.
      if (playerDomEl.readyState >=  playerDomEl.HAVE_METADATA) {
        seekAndAutoPlay(videoJsPlayer, timeCodeSeconds);
      } else {
        playerDomEl.addEventListener("loadedmetadata", function(event) {
          seekAndAutoPlay(videoJsPlayer, timeCodeSeconds);
        });
      }

      // If all else fails, on some very persnickety user-agents (iOS), there's no
      // way to seek UNTIL user presses play. Using video.js event and seek API is also important,
      // as it seems to work around some iOS issues with doing both those operations too!
      //
      // If it runs when not needed cause earlier seek DID work -- it should just be
      // seeking to where we already are anyway!
      videoJsPlayer.one('play', function() { // 'one' will only hook once then de-register
        videoJsPlayer.currentTime(timeCodeSeconds);
        // it's already playing, it will not help to play again, no need we're good.
      });

      // For OH
      //
      // "tab" in anchor will cause other JS code in another file to switch to that tab.
      //
      // If tab in anchor is ToC, we expand to relevant segment.
      //
      // Otherwise, we need to switch to transcript tab and jump to relevant timecode.
      if (hasOhTabs()) {
        if (hashParams.get("tab") == "ohToc") {
          execWhenOhTabActive("ohToc", function() {
            gotoTocSegmentAtTimecode(timeCodeSeconds);
          });
        } else if (hashParams.get("tab") != "ohTranscript") {
          bootstrap.Tab.getOrCreateInstance(
            document.querySelector('*[data-bs-toggle="tab"][href="#ohTranscript"]')
          ).show();

          execWhenOhTabActive("ohTranscript", function() {
            gotoTranscriptTimecode(timeCodeSeconds);
          });
        }
      }
    });
  } else if (paragraphNumber && hasOhTabs()) {
      // OH transcript paragraph number, need to make sure we've switched to transcript tab,
      // then scroll to element leaving room for navbar
      if (hashParams.get("tab") != "ohTranscript") {
        bootstrap.Tab.getOrCreateInstance(
          document.querySelector('*[data-bs-toggle="tab"][href="#ohTranscript"]')
        ).show();
      }

      execWhenOhTabActive("ohTranscript", function() {
        const element = document.querySelector(`#oh-t-p${paragraphNumber}`);
        if (element) {
          scrollToElement(element);
        }
      });
    }
});

// Something has already executed bootstrap tab to switch to targetTabId. But maybe
// it's finished it's transition, maybe it hasn't. We want to execute procArg
// only once/if transition to tab is complete.
function execWhenOhTabActive(targetTabId, procArg) {
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

function hasOhTabs() {
  return !!document.querySelector("#ohmsScrollable .tab-pane.active")
}

// Seek to selected time, and TRY to auto-play the audio. Either or both might
// not work in some browsers trying to prevent spammy playing.
//
// Must be called when player is in a readyState where we can seek,
// at least HAVE_METADATA. https://developer.mozilla.org/en-US/docs/Web/API/HTMLMediaElement/readyState
function seekAndAutoPlay(videoJsPlayer, timeCodeSeconds) {
  videoJsPlayer.currentTime(timeCodeSeconds);

  var playPromise  = videoJsPlayer.play();

  if (playPromise !== undefined) {
    playPromise.catch(error => {
      console.log(`could not autoplay: ${error}`);
    });
  }
}

 // Another file is creating the videoJS object, asyncrornous to this file.
 //
 // It may or may not have already been created; we want to execute the callback
 // only when it has, and not execute the callback if it never does!
function onVideoJSSetupFor(htmlMediaElement, callback) {
  if (! htmlMediaElement) {
    // wasn't even on page, we need do nothing.
    return;
  }

  const existingPlayer = videojs.getPlayer(htmlMediaElement);

  if (existingPlayer) {
    // already exists
    callback(existingPlayer);
  } else {
    videojs.hook('setup', function(createdPlayer) {
      // if multiple on a page, make sure it's the one we want
      if (createdPlayer.el().contains(htmlMediaElement)) {
        callback(createdPlayer);
      }
    });
  }
}

