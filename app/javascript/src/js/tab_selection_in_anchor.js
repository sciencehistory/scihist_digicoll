// Based on https://github.com/twbs/bootstrap/issues/25220
//
// We are using jQuery here, because bootstrap 4 JS for tabs uses/requires
// it anyway.

import domready from 'domready';

domready(function() {
  // if there's an #anchor in the URL referencing a bootstrap tab, make that tab selected.
  // should we limit to only certain data tags instead of all bootstrap tab links?
  const anchor = window.location.hash;
  if (anchor) {
    $(`*[data-toggle="tab"][href="${anchor}"]`).tab("show")
  }

  // when showing on a bootstrap tab, put the relevant ID in anchor,
  // without adding to browser history
  $(document).on("show.bs.tab", function(event) {
    window.history.replaceState(undefined, undefined, event.target.getAttribute("href"));
  });
});

