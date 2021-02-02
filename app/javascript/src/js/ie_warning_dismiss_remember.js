$( document ).ready(function() {
  $('#ieWarning').on('close.bs.alert', function () {
    // Set a cookie so we can now not to show the warning again
    document.cookie = "ieWarnDismiss=1";
  })
});
