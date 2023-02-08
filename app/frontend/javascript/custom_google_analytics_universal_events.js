// Send a custom GA Universal event with data-attributes on a link.
// https://developers.google.com/analytics/devguides/collection/analyticsjs/events
// Note that app/frontend/javascript/custom_google_analytics_universal_events.js
// contains a method that is trigged by the same click.
$(document).on('click', '*[data-analytics-category]', function(e) {

  // Do not call `ga` unless the function is defined
  // in app/views/layouts/_google_analytics_universal.html.erb .
  // (This in turn is controlled by ScihistDigicoll::Env.lookup(:google_analytics_property_id).
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

      // Our HTML never actually defines a data-analytics-value attribute
      // so this always ends up getting sent to GA as `undefined`.
      // We will not be using this in GA 4.
      e.target.getAttribute("data-analytics-value")
    );
  }
});