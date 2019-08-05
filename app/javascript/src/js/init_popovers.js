// Bootstrap 4 popovers are opt-in, we need to activate them.
// https://getbootstrap.com/docs/4.0/components/popovers/#example-enable-popovers-everywhere

// Does use JQuery

import domready from 'domready';

console.log("here in init popovers");
domready(function() {
  debugger;
  $('[data-toggle="popover"]').popover()
});
