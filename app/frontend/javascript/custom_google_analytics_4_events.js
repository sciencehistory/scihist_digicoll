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

    // In certain cases we want to set event_value to the contents of a text input - one that
    // might be different every time the link or button is clicked.

    // Example use case: we want to set event_value to the query string in search-within-the-work search form.

    // If we find a selector in data-analytics-value-css, we can look up the current value of the text input 
    // using that selector, and then pass that string to GA as event_value.
    var elementToLookUp =  e.currentTarget.getAttribute("data-analytics-value-css");
    var eventValue = elementToLookUp ?  $(elementToLookUp)[0].value.replace(/[^a-zA-Z 0-9]+/g, '') : null;

    var data_to_send = {
      // Always the string "work".
      'event_category': e.currentTarget.getAttribute("data-analytics-category"),

      // Always the work's friendlier_id.
      'event_label': e.currentTarget.getAttribute("data-analytics-label"),

      // Only used to send a search phrase (or, more frequently, null).
      'event_value': eventValue
    }

    // Based on https://support.google.com/analytics/answer/13675006?hl=en, let's try a more user-friendly format as well:
    if (eventValue) {
      data_to_send['search_phrase'] = eventValue;
      data_to_send['friendlier_id'] = e.currentTarget.getAttribute("data-analytics-label");
    }


    gtag( 'event',
      // A string describing what the user did,
      // e.g. "download" or "transcription_pdf" or "english_translation_pdf" or "download_original"
      e.currentTarget.getAttribute("data-analytics-action"),
      data_to_send
    );
  }
});

