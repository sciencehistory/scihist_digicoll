import domready from 'domready';
import { Popover } from 'bootstrap';


domready(function() {
  // Find things noted for our custom popover. Look up citation quote and refernece from
  // footnote later in com, and use bootstrap popover to make it a popover here!
  //
  // Use a custom template to make the "title" slot actually at the bottom, and not
  // a header -- we use it for citation referece.

  document.querySelectorAll('[data-shi-toggle=oh-ai-footnote-popover]').forEach( element => {
    const footnote_id = element.getAttribute("data-shi-footnote-ref");

    const footnoteEl = document.getElementById(footnote_id);

    const reference_title = footnoteEl.querySelector("[data-shi-slot=footnote-title]");
    const reference_quote = footnoteEl.querySelector("[data-shi-slot=footnote-quote]");

    const popover = new Popover(element, {
      content: reference_quote,
      title: reference_title,
      trigger: "hover focus",
      placement: "bottom",
      template: `<div class="popover" role="tooltip">
        <div class="popover-arrow"></div>
        <div class="popover-body"></div>
        <div class="popover-header"></div>
      </div>`,
      customClass: "oh-ai-footnote-popover"
    });

  });
});
