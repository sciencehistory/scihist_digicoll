// We open up a modal to show the URL to share this page -- what makes it speical
// is there's a checkbox to add timecode into audio link, to link to certain number
// of sessions.

import domready from 'domready';

domready(function() {
  // Open modal, filling it out with current time
  document.querySelector("*[data-toggle='linkShareModal']")?.addEventListener("click", function(event) {
    event.preventDefault();

    // Store current timecode
    var player = document.querySelector("*[data-role=now-playing-container] audio");
    var currentSeconds = Math.trunc(player.currentTime);

    var humanSlot = document.querySelector("#audioLinkShare *[data-slot='humanTimecode'");
    humanSlot && (humanSlot.innerText = humanReadableSeconds(currentSeconds));

    var slot = document.querySelector("#audioLinkShare input[data-slot='timecode'");
    slot && (slot.value = currentSeconds);

    $('#audioLinkShare').modal();
  });

  // Checkbox click on modal alters URL
  document.querySelector("#audioLinkShare *[data-trigger='updateLinkTimecode']")?.addEventListener("change", function(event) {
    var input = event.target;
    var display = document.querySelector("#audioLinkShare *[data-slot='shareURL']");
    if (input.checked) {
      var seconds = event.target.value;
      display.value = display.value.replace(/#.*$/, '') + "#t=" + input.value;
    } else {
      display.value = display.value.replace(/#.*$/, '');
    }
  });

  // clipboard copy button
  document.querySelector("#audioLinkShare *[data-trigger='linkClipboardCopy']")?.addEventListener("click", function(event) {
    var display = document.querySelector("#audioLinkShare *[data-slot='shareURL']");
    navigator.clipboard.writeText(display.value);
  });
});


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
