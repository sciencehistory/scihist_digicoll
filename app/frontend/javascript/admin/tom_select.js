// use https://tom-select.js.org/ for fancy auto-complete text/select boxes.

// tom-select does not require JQuery, and we use no JQuery in this file.

import 'tom-select/dist/css/tom-select.bootstrap5.min.css';

// Not sure how I figured out these paths to load tom-select base and then selected plugins
// from npm tom-select... but here it is. See: https://github.com/orchidjs/tom-select/issues/57
import TomSelect from 'tom-select/dist/esm/tom-select'; // tom-select base
import 'tom-select/dist/esm/plugins/remove_button/plugin'; // specific desired plugin(s)

import domready from 'domready';

domready(function() {

  // We're just going to add a standard tom-select to any select input that has data-tom-select=true
  // It will not do any AJAX loads, just turn an in-page <select> input into a dynamic tom-select.
  //
  // For now, this is good enough. Later, we could add more functionality in data- attributes,
  // or even just select certain things like "#specificSelect" to configure in certain TomSelect ways.

  document.querySelectorAll('select[data-tom-select]').forEach(function(item) {
    new TomSelect(item,{
      //openOnFocus: false,
      placeholder: "type to filter",
      hidePlaceholder: true,
      closeAfterSelect:  true,
      plugins: ['remove_button']
    });
  });
});
