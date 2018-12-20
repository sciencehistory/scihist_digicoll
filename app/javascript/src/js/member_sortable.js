import domready from 'domready';
import { Sortable } from '@shopify/draggable';
import 'mdn-polyfills/Element.prototype.closest'

domready(function() {
  const sortTrigger = document.querySelector("[data-trigger='member-sort']");

  if (sortTrigger) {
    const saveButton = document.querySelector("[data-trigger='member-sort-save']");
    const sortTable = document.querySelector("[data-trigger='member-sort-table']");
    const sortTbody = sortTable.querySelector("tbody");
    const sortForm = sortTable.closest("form");

    var sortMode = false;
    var sortable;

    sortTrigger.addEventListener("click", function(event) {
      sortMode = !sortMode;

      if(sortMode) {
        if(!sortable) {
          sortable = new Sortable(sortTbody, {
            draggable: 'tr'
          });
          sortable.on("drag:stop", function() { if(saveButton) { saveButton.disabled = false; } });
          sortForm.setAttribute("action", sortForm.getAttribute("data-submit-url"));
          sortForm.classList.add("sorting");
        }
      } else { // turning sortMode off
        if (sortable) {
          sortable.destroy();
          sortable = undefined;
          sortForm.removeAttribute("action");
          sortForm.classList.remove("sorting");
        }
      }
    });
  }


    // sortable.on('sortable:start', () => console.log('sortable:start'));
    // sortable.on('sortable:sort', () => console.log('sortable:sort'));
    // sortable.on('sortable:sorted', () => console.log('sortable:sorted'));
    // sortable.on('sortable:stop', () => console.log('sortable:stop'));

});
