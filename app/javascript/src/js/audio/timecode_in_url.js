// Allow timecodes to be in urls in fragment identifier, like #t=[number of seconds]
//
// And we'll jump to that timecode in our OH audio player.
//
// This is influenced by w3c media fragment standard. https://www.w3.org/TR/media-frags/
//
// * Note we also have a different mechanism of jumping to a timecode in `play_at_timecode.js`.
// We could rationalize them in the future?
//
// * Note we also use `#`` fragment identifiers in somewhat inconsistent way, at `tab_selection_in_anchor.js`. `
//
// This file avoids using jQuery.

import domready from 'domready';

domready(function() {
  const anchor = window.location.hash;

  if (anchor && anchor.includes('=')) {

    // parse out #t=1212&maybeother=thing
    var pairs = anchor.substring(1).split("&");
    var hashParams = {};
    for (var i = 0; i < pairs.length; i++) {
        var pair = pairs[i].split('=');
        hashParams[decodeURIComponent(pair[0])] = decodeURIComponent(pair[1] || '');
    }

    var html5Audio = document.querySelector("*[data-role=now-playing-container] audio");

    if (hashParams["t"] && html5Audio) {
      var seconds = hashParams["t"];
      html5Audio.currentTime = seconds;

      // Chrome and maybe other browsers don't let us play audio
      // on load anymore. User has to press play. But we'll try if the browser lets us.
      // https://developers.google.com/web/updates/2017/09/autoplay-policy-changes
      var playPromise = html5Audio.play();
      playPromise.catch(error => {
        console.log("Could not autoplay audio: " + error);
      });

    }
  }
});
