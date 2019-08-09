// Bootstrap 4 popovers are opt-in, we need to activate them.
// https://getbootstrap.com/docs/4.0/components/popovers/#example-enable-popovers-everywhere

// Does use JQuery

import domready from 'domready';

domready(function() {
  $('[data-toggle="popover"]').popover()
});
