// Send a custom GA Universal event with data-attributes on a link.
// https://developers.google.com/analytics/devguides/collection/analyticsjs/events
// Note that app/frontend/javascript/custom_google_analytics_universal_events.js
// contains a method that is trigged by the same click.
$(document).on('click', '*[data-analytics-category]', function(e) {
  if (typeof ga === 'function') {
    ga('send', 'event',
      // This is a string describing what the user did,
      // e.g. "download" or "transcription_pdf" or "english_translation_pdf" or "download_original"
      // This becomes the`event_category` in `gtag` in GA 4.
      e.target.getAttribute("data-analytics-category"),

      // This is a string describing what the user did,
      // e.g. "download" or "transcription_pdf" or "english_translation_pdf" or "download_original"
      // This becomes the second argument of `gtag` in GA 4.
      e.target.getAttribute("data-analytics-action"),

      // This is currently always the work's friendlier_id.
      // This will become event_label in GA 4.
      e.target.getAttribute("data-analytics-label"),    

      // Our code currently sends a null value for this param.
      e.target.getAttribute("data-analytics-value")
    );
  }
});