// There is a problem with blacklight_range_limit rendered chart (that we use for date range
// facet), where it sometimes doesn't wind up with the right size.
//
// In at least some cases, it looks like the size is being calculated before load,
// and if we force it to be reiszed on `load` event (not to be confused with earlier DOMContentLoaded),
// it can get fixed.
//
// We don't have an explicit wait to tell blacklight_range_limit "resize the chart", but
// we can trick it into doing so by sending a fake `shown.bs.collapse`. We do on the 'load'
// event.
//
// https://github.com/sciencehistory/scihist_digicoll/issues/270
// https://github.com/projectblacklight/blacklight_range_limit/issues/111
//
// This isn't necessary if the facet didn't start out open. It's unclear if this
// actually resolves the problem entirely.

window.addEventListener('load', function(event) {
  $("#facet-year_facet_isim:visible").trigger("shown.bs.collapse");
});
