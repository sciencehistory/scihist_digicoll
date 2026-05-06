import domready from 'domready';

// Let's you put in fragment #modal-auto-open=$id
//
// and if id is on that page with a modal trigger, will trigger it on page load.
//
// Motivated by linking to OH page with an auto open of request button.

domready(function() {
  // remove initial "#" from fragmentIdentifier, then parse like query.
  const hashParams = new URLSearchParams(window.location.hash.slice(1));

  const id = hashParams.get("modal-auto-open");
  if (id) {
    const element = document.querySelector(`#${id}`);
    if (element) {
      element.click();
    }
  }
});
