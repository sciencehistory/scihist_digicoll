// Seeking a video.js player to a timecode, shared by Oral History audio and
// work show video.
//
// IMPORTANT: written against the video.js Player API only, never a captured
// <video>/<audio> DOM element. The Player object survives a change of loaded
// media (eg switching segments of a multi-segment video work), but the underlying
// tech element is disposed and replaced -- so a `loadedmetadata` listener left on
// the element would be sitting on a detached node, and never fire.

// https://developer.mozilla.org/en-US/docs/Web/API/HTMLMediaElement/readyState
const HAVE_METADATA = 1;

// Seek to timeCodeSeconds and try to auto-play, now if the player can already
// seek, otherwise once it can.
export function seekAndAutoPlayWhenReady(player, timeCodeSeconds) {
  // Try to seek and then auto-play. player might not be in state where it can
  // seek yet, if it is not then try to wait and seek when we can.
  if (player.readyState() >= HAVE_METADATA) {
    seekAndAutoPlay(player, timeCodeSeconds);
  } else {
    player.one("loadedmetadata", function() {
      seekAndAutoPlay(player, timeCodeSeconds);
    });
  }

  // If all else fails, on some very persnickety user-agents (iOS), there's no
  // way to seek UNTIL user presses play. Using video.js event and seek API is also
  // important, as it seems to work around some iOS issues with doing both those
  // operations too!
  //
  // If it runs when not needed cause earlier seek DID work -- it should just be
  // seeking to where we already are anyway!
  player.one("play", function() { // 'one' will only hook once then de-register
    player.currentTime(timeCodeSeconds);
    // it's already playing, it will not help to play again, no need we're good.
  });
}

// Seek to selected time, and TRY to auto-play. Either or both might not work in
// some browsers trying to prevent spammy playing.
//
// Must be called when player is in a readyState where we can seek, at least
// HAVE_METADATA.
export function seekAndAutoPlay(player, timeCodeSeconds) {
  player.currentTime(timeCodeSeconds);

  var playPromise = player.play();

  if (playPromise !== undefined) {
    playPromise.catch(error => {
      console.log(`could not autoplay: ${error}`);
    });
  }
}
