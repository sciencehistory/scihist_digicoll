// Send a custom GA event with data-attributes on a link.
//
// https://developers.google.com/analytics/devguides/collection/analyticsjs/events

$(document).on('click', '*[data-analytics-category]', function(e) {

  // Google Analytics Universal.
  if (typeof ga === 'function') {
    ga('send', 'event',
      // This is a string describing what the user did,
      // e.g. "download" or "transcription_pdf" or "english_translation_pdf" or "download_original"
      // This becomes the`event_category` in `gtag` below.
      e.target.getAttribute("data-analytics-category"),

      // This is a string describing what the user did,
      // e.g. "download" or "transcription_pdf" or "english_translation_pdf" or "download_original"
      // This becomes the second argument of `gtag` below.
      e.target.getAttribute("data-analytics-action"),

      // This is currently always the work's friendlier_id.
      // This will become event_label below.
      e.target.getAttribute("data-analytics-label"),    

      // Our code currently sends a null for this.
      e.target.getAttribute("data-analytics-value")
    );
  }

  // Google Analytics 4.0.
  // Details about migrating to the GA4 event tracker are here:
  // https://developers.google.com/analytics/devguides/migration/ua/analyticsjs-to-gtagjs#measure_events_with_the_default_tracker
  if (typeof gtag === 'function') {
    gtag( 'event',

      // param eventName
      // A string describing what the user did,
      // e.g. "download" or "transcription_pdf" or "english_translation_pdf" or "download_original"
      e.target.getAttribute("data-analytics-action"),

      {
        // This is currently always the string "work".
        'event_category': e.target.getAttribute("data-analytics-category"),
        // This is currently always the work's friendlier_id.
        'event_label':    e.target.getAttribute("data-analytics-label"),
      }

    );
  }
});