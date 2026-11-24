// Fills in the current page's local URL (path, query, and #fragment), e.g. for a `return_to`,
// to come back to the same spot (such as an AI citation paragraph) after registering or signing in.
// Browsers never send the #fragment to the server, so the server can't do this itself.
//
// * input[data-set-current-url]: on form submit, value set to current URL
// * a[data-set-current-url="param_name"]: on click, that query param set to current URL
//
// Works in a Blacklight modal, where location is still the page that opened it.

function currentUrl() {
  return window.location.pathname + window.location.search + window.location.hash;
}

// capture phase, so it runs before the modal's own submit handler reads the form
document.addEventListener("submit", (event) => {
  event.target.querySelectorAll("input[data-set-current-url]").forEach((input) => {
    input.value = currentUrl();
  });
}, true);

document.addEventListener("click", (event) => {
  const link = event.target.closest("a[data-set-current-url]");
  if (!link) return;

  const url = new URL(link.href);
  url.searchParams.set(link.dataset.setCurrentUrl, currentUrl());
  link.href = url.toString();
}, true);
