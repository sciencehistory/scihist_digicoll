// Bootstrap 4 popovers are opt-in, we need to activate them.
// https://getbootstrap.com/docs/4.0/components/popovers/#example-enable-popovers-everywhere

jQuery( document ).ready(function() {
  $('[data-toggle="popover"]').popover()
});
