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

  var html5Audio = $("*[data-role=now-playing-container] audio").get(0);

  html5Audio.currentTime = seconds;
  html5Audio.play();
});
