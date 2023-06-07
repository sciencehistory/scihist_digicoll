// Send a custom Google Analytics event with data-attributes on a link.
// Details about migrating to the GA4 event tracker are here:
// https://developers.google.com/analytics/devguides/migration/ua/analyticsjs-to-gtagjs#measure_events_with_the_default_tracker
// Note that app/frontend/javascript/custom_google_analytics_universal_events.js
// contains a method that is trigged by the same click.
$(document).on('click', '*[data-analytics-category]', function(e) {

  // Do not call `gtag` unless the function is defined
  // in app/views/layouts/_google_analytics_4.html.erb .
  // (This in turn is controlled by ScihistDigicoll::Env.lookup(:google_analytics_4_tag_id).
  if (typeof gtag === 'function') {

    gtag( 'event',

      // param eventName
      // A string describing what the user did,
      // e.g. "download" or "transcription_pdf" or "english_translation_pdf" or "download_original"
      e.target.getAttribute("data-analytics-action"),
      {
        // As of early 2023, this is always the string "work".
        'event_category': e.target.getAttribute("data-analytics-category"),
        // As of early 2023, this is always the work's friendlier_id.
        'event_label':    e.target.getAttribute("data-analytics-label"),
      }

    );
  }
});