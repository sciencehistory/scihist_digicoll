// JS for our local custom OHMS footnotes.
//

var OhmsFootnotes = {};
jQuery(document).ready(function() {
    OhmsFootnotes.setUpFootnoteEvents();
});

// Based off http://hiphoff.com/creating-hover-over-footnotes-with-bootstrap/

OhmsFootnotes.setUpFootnoteEvents = function() {
  jQuery('[data-toggle="tooltip"]').each(function() {
      var $elem = jQuery(this);
      $elem.tooltip({
          // sets the container to be the span
          // element that contains the footnote,
          // which will prevent a mouseout event
          // from being logged when the user
          // moves from the footnote number
          // to the footnote text.
          container: $elem,

          // prevents the text box from hiding for
          // 400 milliseconds after a mouseout.
          // This prevents the tooltip from vanishing
          // if the user moves their mouse from the
          //   footnote number to the tooltip via
          // a path that’s outside either element,
          // momentarily mousing out.
          delay: {hide:400}
      });
  });
}