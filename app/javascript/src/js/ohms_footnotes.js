// JS for our local custom OHMS footnotes.
// Based on http://hiphoff.com/creating-hover-over-footnotes-with-bootstrap/
// Corresponging HTML is in:
// app/views/presenters/_ohms_footnote_reference.html.erb

// The selector we use for these is: data-toggle="ohms-tooltip"]
// Note that generic Bootstrap tooltips are also being
// used on the site: see app/javascript/src/js/bootstrap_tooltips_activate.js .


var OhmsFootnotes = {};

jQuery(document).ready(function() {
    OhmsFootnotes.setUpFootnoteEvents();
});

OhmsFootnotes.setUpFootnoteEvents = function() {
  // Show the tooltip if you hover over a footnote referecne.
  jQuery('[data-toggle="ohms-tooltip"]').each(function() {
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
  // If you click on a footnote reference, takes you up to the corresponding footnote.
  jQuery('[data-role="footnote-reference"]').each(function() {
      jQuery(this).click(function(event){ OhmsFootnotes.jump(event, jQuery(this), 'footnote') });
  });
  // Likewise, if you click on a footnote in the footnote section, takes you back up to the reference to it in the text.
  jQuery('[data-role="footnote-page-bottom"]').each(function() {
      jQuery(this).click(function(event){ OhmsFootnotes.jump(event, jQuery(this), 'footnote-reference') });
  });
}

// Jump down to a footnote or up to a reference.
// prefix is 'footnote-reference' for references, 'footnote' for footnote
OhmsFootnotes.jump = function(event, item_clicked, prefix) {
  event.preventDefault();
  var destination = jQuery('#' + prefix + item_clicked.data()['footnoteIndex'])
  window.scrollTo({top: destination.offset().top - jQuery("#ohmsAudioNavbar").height()});
}
