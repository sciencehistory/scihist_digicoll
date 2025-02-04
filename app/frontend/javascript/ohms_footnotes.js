// JS for our local custom OHMS footnotes.
// Based on http://hiphoff.com/creating-hover-over-footnotes-with-bootstrap/
// Corresponging HTML is in OralHistory::FootnoteReferenceComponent

// The selector we use for these is: data-toggle="ohms-tooltip"]
// Note that generic Bootstrap tooltips are also being
// used on the site: see app/javascript/src/js/bootstrap_tooltips_activate.js .


var OhmsFootnotes = {};

jQuery(document).ready(function() {
    OhmsFootnotes.setUpFootnoteEvents();
});

OhmsFootnotes.setUpFootnoteEvents = function() {
  // Show the tooltip if you hover over a footnote referecne.
  jQuery('[data-toggle="ohms-reference"]').each(function() {
    var $elem = jQuery(this);
    $elem.popover({
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

  // If you click on a ohms-navbar-aware-internal-link, we need to scroll to there,
  // but leaving space for ohms fixed navbar, that the browser ordinarily won't.
  jQuery('[data-role="ohms-navbar-aware-internal-link"]').each(function() {
      jQuery(this).click(function(event){
        var anchor = this.attributes['href'] && this.attributes['href'].value;
        OhmsFootnotes.jump(event, anchor)
      });
  });
}

// Jump to a certain "#pageId", but leaving space for our fixed navbar on top.
OhmsFootnotes.jump = function(event, destination) {
  event.preventDefault();
  var destination = jQuery(destination);
  window.scrollTo({top: destination.offset().top - jQuery("#ohmsAudioNavbar").outerHeight() - 8});
}
