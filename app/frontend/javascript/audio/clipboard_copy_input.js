import domready from 'domready';

domready(function() {

  // clipboard copy button,
  // is on a bootstrap input group with a read-only input with
  // url, and a button to trigger clipboard copy.
  //
  //  * data-trigger=copyInputGroup => the bootstrap input-group parent.
  //  * data-slot='shareURL' => the readonly input whose value() is the url (child of copyInputGroup)
  //  * data-trigger='linkClipboardCopy => the copy button (child of copyInputGroup)
  document.querySelectorAll("*[data-trigger='copyInputGroup'] *[data-trigger='linkClipboardCopy']").forEach(function(element) {
    element.addEventListener("click", function(event) {
      var button = event.currentTarget;
      var display = event.currentTarget.closest("*[data-trigger='copyInputGroup']").querySelector("*[data-slot='shareURL']");

      navigator.clipboard.writeText(display.value).then(function() {
        button.setAttribute("title", "Copied to clipboard");
        button.classList.add("btn-outline-success");
        button.classList.remove("btn-outline-secondary");


        jQuery(button).tooltip({trigger: "manual"}).tooltip("show");

        // remove em after a few seconds....
        setTimeout(function() {
          var jQueryButton = jQuery(button);

          jQueryButton.tooltip("hide");
          button.classList.add("btn-outline-secondary");
          button.classList.remove("btn-outline-success");

          jQueryButton.one('hidden.bs.tooltip', function(e) {
            button.removeAttribute("title");
            jQueryButton.tooltip("dispose");
          });

        }, 3500);
      });
    });
  });

});
