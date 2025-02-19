// If an ordinary hyperlink is marked with data-turnstile-protected=true,
// we will put up a quick bootstrap modal form to do a turnstile bot challenge
// before sending them on to their ordinary destination via a GET request.
//
// Also target data-analytics-action=downloadOriginal, lazy way to avoid having
// to add attribute to those links thanks.

import domready from 'domready';
import * as bootstrap from 'bootstrap';

domready(function() {
  var loadedWidgetId;

  document.querySelector("a[data-turnstile-protection=true],a[data-analytics-action=download_original]")?.addEventListener("click", function(event) {
    // Hacky exempt if it's a PDF download, because we want google to crawl PDFs
    // We can tell only by href path sorry
    if (event.currentTarget.getAttribute("href")?.includes('downloads/orig/pdf')) {
      return;
    }

    event.preventDefault();
    const origHref = event.currentTarget.getAttribute("href");

    addTurnstileJsIfNecessary().then(() => {
      const modal = bootstrap.Modal.getOrCreateInstance(document.getElementById("turnstile-protected-link-modal"));
      modal.show();

      const widgetWrapper = document.getElementById('turnstile-protected-link-widget');
      const siteKey = widgetWrapper.getAttribute("data-sitekey");

      if (loadedWidgetId) {
        window.turnstile.reset(loadedWidgetId);
      } else {
        loadedWidgetId = window.turnstile.render(widgetWrapper, {
          sitekey: siteKey,
          callback: function(token) {
            // We're going to redirect with token visible in URL, but since
            // we plan to use this right now only for URL that's going to immediately
            // redirect anyway, no problem.

            var newUrl;
            if (origHref.indexOf('?') === -1) {
              newUrl = origHref + "?cf_turnstile_response=" + encodeURIComponent(token);
            } else {
              url += '&' + "cf_turnstile_response=" + encodeURIComponent(token);
            }

            // likely media that will download and not actualy change browser
            window.location.assign(newUrl);
            modal.hide();
          }
        });
      }

    });
  });
});


function addTurnstileJsIfNecessary() {
  if (window.turnstile) {
    // Already loaded, return immediate promise
    return Promise.resolve(undefined);
  } else {
    // Add a script tag, with promise that will resolve after
    return new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = "https://challenges.cloudflare.com/turnstile/v0/api.js";
      script.onload = resolve;
      script.onerror = reject;
      document.head.appendChild(script);
    });
  }
}
