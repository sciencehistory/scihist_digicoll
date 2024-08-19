// Send a custom Google Analytics event with data-attributes on a link.
// Details about migrating to the GA4 event tracker are here:
// https://developers.google.com/analytics/devguides/migration/ua/analyticsjs-to-gtagjs#measure_events_with_the_default_tracker


// The easiest way to do this is to add an argument like:
// data: {
//   'analytics-category' => 'Work',
//   'analytics-action' =>   "transcription_pdf",
//   'analytics-label' =>    work.friendlier_id,
//   'analytics-value' =>    search_phrase
// }
// to any call to `link_to`.


// To report an event to Google Analytics directly from arbitrary JS code, use:
//
// import { reportEventToGA } from '../javascript/custom_google_analytics_4_events';
// [...]
// reportEventToGA('search_inside', 'work', this.workId, query);
//
// See scihist_viewer.js for an example.


$(document).on('click', '*[data-analytics-category]', function(e) {
  reportEventToGA(
    e.target.getAttribute("data-analytics-action"),
    e.target.getAttribute("data-analytics-category"),
    e.target.getAttribute("data-analytics-label"),
    e.target.getAttribute("data-analytics-value"),
  );
});

export function reportEventToGA(action, category, label, value) {

  if (action == null) {
    return;
  }

  // alert("Reporting to GA. action is " + action + " and category is " + category + " and label is " + label + " and value is " + value );

  // Do not call `gtag` unless the function is defined
  // in app/views/layouts/_google_analytics_4.html.erb .
  // (This in turn is controlled by ScihistDigicoll::Env.lookup(:google_analytics_4_tag_id).
  if (typeof gtag !== 'function') {
    return;
  }

  gtag( 'event',
    
    // A string describing what the user did,
    // e.g. "download" or "transcription_pdf" or "english_translation_pdf" or "download_original" or "search_inside"
    action,

    {
      // As of 2024, this is always the string "work".
      'event_category': category,

      // As of 2024, this is always the work's friendlier_id.
      'event_label':   label,

      // As of 2024 this is only used to send the search phrase in app/frontend/javascript/scihist_viewer.js .
      // The rest of the time we've just left it null.
      'event_value':    value
    }

  );
  
}
