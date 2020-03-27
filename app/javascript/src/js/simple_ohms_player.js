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

function showDuration() {
    var startTime = parseFloat(this.dataset.ohmsTimestampS);
    var nextTrack = jQuery(this).next('.track-listing')
    var endTime = jQuery('audio')[0].duration;
    if (nextTrack.length > 0) {
        endTime = parseFloat(nextTrack[0].dataset.ohmsTimestampS);
    }
    durationInSeconds = endTime - startTime
    durationInMinutes = durationInSeconds / 60.0
    roundedDurationInMinutes = Math.round(durationInMinutes * 10.0) / 10.0
    jQuery(this).find("*[data-role=track-duration]").html(roundedDurationInMinutes);
}

jQuery('audio')[0].onloadedmetadata = function () {
    jQuery(".track-listing").each(showDuration);
};