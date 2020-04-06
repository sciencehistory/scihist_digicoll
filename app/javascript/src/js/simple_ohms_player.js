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
