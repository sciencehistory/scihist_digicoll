// JS for our local custom OHMS footnotes.
//

var OhmsFootnotes = {};

jQuery(document).ready(function() {
    OhmsFootnotes.AddFootnotes();
    OhmsFootnotes.setUpFootnoteEvents();
});

// Based off http://hiphoff.com/creating-hover-over-footnotes-with-bootstrap/

OhmsFootnotes.setUpFootnoteEvents = function() {
  jQuery('[data-toggle="tooltip"]').each(function() {
      var $elem = jQuery(this);
      $elem.tooltip({
          html:true,

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

OhmsFootnotes.footnoteHTML =  function(footnoteNumber, footnoteText) {
  var _self = this;
  var escapedFootnote = _self.escapeHtml(footnoteText)
  return "<span class=\"footnote\" data-toggle=\"tooltip\" title=\"" + escapedFootnote + "\">" +
      "<sup>" +
        footnoteNumber +
      "</sup>" +
    "</span>";
  // return "<a href=\"#\" data-toggle=\"tooltip\" title=\""+ escapedFootnote + ""\">" + footnote_number+ "</a>";

};


OhmsFootnotes.escapeHtml =  function(string) {
  var entityMap = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
    '/': '&#x2F;',
    '`': '&#x60;',
    '=': '&#x3D;'
  };
  return String(string).replace(/[&<>"'`=\/]/g, function (s) {
    return entityMap[s];
  });
}


OhmsFootnotes.footnoteData = function() {
  var _self = this;
  return JSON.parse($("div[data-role='footnotes_as_json']").html());
}

OhmsFootnotes.AddFootnotes = function() {
  var _self = this;
  var footnoteData = _self.footnoteData();
  var find_re = new RegExp(/\[\[footnote\]\](\d+)\[\[\/footnote\]\]/);
  return $(".ohms-transcript-line").map(function() {
    var line = $(this);
    var match = line.text().match(find_re);
    if (match) {
        var footnoteNumber = parseInt(match[1]);
        var replacement = _self.footnoteHTML(footnoteNumber, footnoteData[footnoteNumber - 1]);
        line.html(line.html().replace(match[0], replacement));
    }
  });
}