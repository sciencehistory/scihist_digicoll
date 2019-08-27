// Ability to send a custom GA event with data- attributes on a link.
//
// https://developers.google.com/analytics/devguides/collection/analyticsjs/events
//
// We use for tracking download and viewer links, possibly among other things.

$(document).on('click', '*[data-analytics-category]', function(e) {
  ga('send',
      e.target.getAttribute("data-analytics-category"),
      e.target.getAttribute("data-analytics-action"),
      e.target.getAttribute("data-analytics-label"),
      e.target.getAttribute("data-analytics-value")
  );
});

