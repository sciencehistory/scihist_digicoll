// use https://tom-select.js.org/ for fancy auto-complete text/select boxes.

// tom-select does not require JQuery, and we use no JQuery in this file.

import 'tom-select/dist/css/tom-select.bootstrap5.min.css';

// https://tom-select.js.org/docs/plugins/
import TomSelect from 'tom-select/dist/js/tom-select.base.js';
import TomSelect_remove_button from 'tom-select/dist/js/plugins/remove_button.js';
import domready from 'domready';

TomSelect.define('remove_button', TomSelect_remove_button);

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
