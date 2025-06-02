// Very simple, click on a link like:
//
//     <a data-ohms-timestamp-s="43"></a>
//
// And it will advance the audio player to that number of seconds. Used in ohms player,
// also used on 'downloads' tab in OH audio.
//
// Audio player is found by finding a HTML5 audio element in a
// container `data-role="now-playing-container"`

$(document).on("click", "*[data-ohms-timestamp-s]", function(event) {
  event.preventDefault();

  var seconds = this.dataset.ohmsTimestampS;

  // OH audio player, or our video player
  var html5Media = $("*[data-role=now-playing-container] audio, .show-video video").get(0);

  html5Media.currentTime = seconds;
  html5Media.play();
});
