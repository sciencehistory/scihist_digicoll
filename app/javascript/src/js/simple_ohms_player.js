// JS we need for our local custom OHMS player func.
//
// Yeah, we'll use JQuery, sorry.

$(document).on("click", "*[data-ohms-timestamp-s]", function(event) {
  event.preventDefault();

  var seconds = this.dataset.ohmsTimestampS;

  var html5Audio = $("*[data-role=now-playing-container] audio").get(0);

  html5Audio.currentTime = seconds;
  html5Audio.play();
});


////////////
////////////
// START HACK
//
// Let's temporarily rig the front end to display the starting point
// of each segment, as well as its duration.
// The starting points are stored in the DB;
// we can redily calculate the duration of each segment
// by subtracting its start time from its end time.
//
// The way we get the end time of the last element is a hack that
// we definitely won't want to keep in the long run:
// loading the combined audio into the DOM and then asking the browser
// to give us the length of the audio tag.
//

function showDuration() {
    var startTime = parseFloat(this.dataset.ohmsTimestampS);
    var nextTrack = jQuery(this).next('.track-listing');
    var endTime;
    if (nextTrack.length) {
        // this track ends when the next one begins
        endTime = parseFloat(nextTrack[0].dataset.ohmsTimestampS);
    }
    else {
        // this track ends when the combined audio ends
        endTime = jQuery('audio')[0].duration;
    }
    var durationInSeconds = endTime - startTime;
    var durationInMinutes = durationInSeconds / 60.0;
    var roundedDurationInMinutes = Math.round(durationInMinutes * 10.0) / 10.0;
    jQuery(this).find("*[data-role=track-duration]").html(roundedDurationInMinutes);
}

// Wait until we have the length metadata for the total play.
// We're temporarily rigging the front end to display
jQuery('audio')[0].onloadedmetadata = function () {
    jQuery(".track-listing").each(showDuration);
};

//
//
// END HACK
////////////
////////////
