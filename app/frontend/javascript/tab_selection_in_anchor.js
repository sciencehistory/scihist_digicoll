// Informed by https://github.com/twbs/bootstrap/issues/25220
//
// We will store current tab selection in "anchor" as #tab=[tabID],
// the query param format in anchor is compatible with storing additional things
// there too, like timecodes. Then we tag on page load if we see an anchor. This
// let's user bookmark specific tab selections. Motivated by Oral History Audio navbar.
//
// Uses jQuery here only for bootstrap 4 JS tabs which uses/requires it.

import domready from 'domready';
import * as bootstrap from 'bootstrap';

domready(function() {
  // if there's an #anchor in the URL referencing a bootstrap tab, make that tab selected.
  // should we limit to only certain data tags instead of all bootstrap tab links?
  var anchor = new URLSearchParams(window.location.hash.replace(/^#/, '')).get("tab");
  if (anchor) {
    bootstrap.Tab.getOrCreateInstance(
      document.querySelector(`*[data-bs-toggle="tab"][href="#${anchor}"]`)
    ).show();
  }

  // when showing on a bootstrap tab, put the relevant ID in anchor,
  // without adding to browser history
  $(document).on("show.bs.tab", function(event) {
    var anchorValues = new URLSearchParams(window.location.hash.replace(/^#/, ''));
    var tabId = event.target.getAttribute("href").replace(/^#/,"")

    anchorValues.set("tab", tabId);
    window.history.replaceState(undefined, undefined, "#" + anchorValues.toString());
  });
});

