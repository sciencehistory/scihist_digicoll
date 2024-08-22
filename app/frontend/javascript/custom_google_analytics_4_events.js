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
    var elementToLookUp =  this.getAttribute("data-analytics-value-css");
    var eventValue = elementToLookUp ?  $(elementToLookUp)[0].value.replace(/[^a-zA-Z 0-9]+/g, '') : null;

    gtag( 'event',

      // A string describing what the user did,
      // e.g. "download" or "transcription_pdf" or "english_translation_pdf" or "download_original" or "search_inside"
      this.getAttribute("data-analytics-action"),

      {

        // This is always the string "work".
        'event_category': e.target.getAttribute("data-analytics-category"),

        // This is always the work's friendlier_id.
        'event_label': this.getAttribute("data-analytics-label"),

        // This is only used to send a search phrase (or, more frequently, null).
        'event_value': eventValue

      }
    );
  }
});

