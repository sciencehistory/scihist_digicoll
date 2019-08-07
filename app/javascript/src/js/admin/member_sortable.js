import domready from 'domready';
import { Sortable } from '@shopify/draggable';
import 'mdn-polyfills/Element.prototype.closest'

domready(function() {
  const sortForm = document.querySelector("[data-trigger='member-sort']")

  if (sortForm) {
    const saveButton = sortForm.querySelector("[data-trigger='member-sort-save']");
    const sortTable = sortForm.querySelector("[data-trigger='member-sort-table']");
    const sortTbody = sortTable.querySelector("tbody");

    const sortable = new Sortable(sortTbody, {
      draggable: 'tr'
    });

    sortable.on("drag:stop", function() { if(saveButton) { saveButton.disabled = false; } });
  }
});
