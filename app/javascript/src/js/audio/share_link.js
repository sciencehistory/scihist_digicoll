// We open up a modal to show the URL to share this page -- what makes it speical
// is there's a checkbox to add timecode into audio link, to link to certain number
// of sessions.

import domready from 'domready';


// on switching to share tab, make sure it's filled out with current time.
// don't think we need to wait for domready on this, and we do need to make
// sure we get it registered before anything switches tabs, including
// tab_selection_in_anchor.js.
$(document).on("shown.bs.tab", "#ohShareTab", function(event) {
  setupTimecode();
});


domready(function() {
  // Checkbox click to include timecode alters url
  document.querySelector("*[data-area='media-link-share'] *[data-trigger='updateLinkTimecode']")?.addEventListener("change", function(event) {
    updateUrlForTimecodeCheckbox(event.target);
  });

  // clipboard copy button
  document.querySelector("*[data-area='media-link-share'] *[data-trigger='linkClipboardCopy']")?.addEventListener("click", function(event) {
    var display = document.querySelector("*[data-area='media-link-share'] *[data-slot='shareURL']");
    navigator.clipboard.writeText(display.value);
  });
});

// Store current timecode in share area
function setupTimecode() {
  var player = document.querySelector("*[data-role=now-playing-container] audio");
  var currentSeconds = Math.trunc(player.currentTime);

  var humanSlot = document.querySelector("*[data-area='media-link-share'] *[data-slot='humanTimecode'");
  humanSlot && (humanSlot.innerText = humanReadableSeconds(currentSeconds));

  var slot = document.querySelector("*[data-area='media-link-share'] input[data-slot='timecode'");
  slot && (slot.value = currentSeconds);
}

function updateUrlForTimecodeCheckbox(input) {
  var display = document.querySelector("*[data-area='media-link-share'] *[data-slot='shareURL']");
  if (input.checked) {
    var seconds = event.target.value;
    display.value = display.value.replace(/#.*$/, '') + "#t=" + input.value;
  } else {
    display.value = display.value.replace(/#.*$/, '');
  }
}


// hh:mm:ss, copied from https://stackoverflow.com/a/21456087/307106
function humanReadableSeconds(seconds) {
  var seconds = parseInt(seconds, 10); // don't forget the second param
  var hours   = Math.floor(seconds / 3600);
  var minutes = Math.floor((seconds - (hours * 3600)) / 60);
  seconds = seconds - (hours * 3600) - (minutes * 60);

  if (hours   < 10) {hours   = "0"+hours;}
  if (minutes < 10) {minutes = "0"+minutes;}
  if (seconds < 10) {seconds = "0"+seconds;}

  var time    = hours+':'+minutes+':'+seconds;
  return time;
}
