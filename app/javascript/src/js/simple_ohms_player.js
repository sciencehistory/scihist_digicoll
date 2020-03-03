// JS we need for our local custom OHMS player func.
//
// Yeah, we'll use JQuery, sorry.

$(document).on("click", "*[data-ohms-timestamp-s]", function(event) {
  event.preventDefault();

  var seconds = this.dataset.ohmsTimestampS;

  var html5Audio = $("*[data-role=now-playing-container] audio").get(0);

  html5Audio.currentTime = seconds;
  html5Audio.play();
});


// okay the SEARCH is the crazier part

// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Regular_Expressions
var escapeRegExp = function(string) {
  return string.replace(/[.*+\-?^${}()|[\]\\]/g, '\\$&'); // $& means the whole matched string
}


// Orginal OHMS viewer does searching server-side, and then only uses JS to highlight
// findings in identified DOM IDs.
//
// We are trying to do the searching all client side instead. If it doesn't work out, we
// can always go to server-side. We are also trying to do the code for searching ourselves,
// instead of using an existing solution like https://markjs.io/
//
// Some of our search code is BASED on what original ohms-viewer uses for highlighting. The
// ohms-viewer code seems to be located in https://github.com/uklibraries/ohms-viewer/blob/45e0ab6df2388ce4e9704c89ce16f4ece953e2de/js/toggleSwitch.js
//
// We DO use JQuery at the moment, sorry.
var Search = {

  wrapInHighlight: function(match) {
    return "<span class=\"ohms-highlight text-danger\">" + match + "</span>";
  },


  // Returns 'result' objects, how do we make one of them?
  // context, tab id, id.
  //
  // looks through all objects that are .ohms-transcript-line,
  // that works for our DOM. Should we add a data- hook?
  //
  // Highlights every hit. For every hit, also calls
  // the addSearchResult hook with a result object.
  searchTranscript: function(query) {
    var _self = this;

    // These are borrowed from ohms-viewer, trying to avoid HTML tags I think?
    if (/^((?!chrome|android).)*safari/i.test(navigator.userAgent) || navigator.userAgent.search("Firefox")) {
        var reStr = "(?![^<>]*(([\/\"']|]]|\b)>))(" + escapeRegExp(query) + ')';
    } else {
        var reStr = '(?<!</?[^>]*|&[^;]*)(' + escapeRegExp(query) + ')';
    }

    // one we'll use for replacing with highlight. Used on HTML.
    var replace_re = new RegExp(reStr, 'gi');
    // one we'll use for capturing with some surrounding context, up to one word before and 4 after.
    // Used on pure text. Capture groups will be:
    // 0 (actual match, not capture group): result in context with before and after
    // 1: before match
    // 2: match
    // 3: after match
    var find_re = new RegExp("((?:\\S*\\s+\\S*){0,1})(" + query + ")((?:\\s*\\S+\\s*){0,4})")

    $(".ohms-transcript-line").each(function() {
      var line = $(this);

      var lineId = this.id;
      var match = line.text().match(find_re);

      if (match) {
        var highlightedMatch = match[1] + _self.wrapInHighlight(match[2]) + match[3];

        // Actually highlight in source HTML, using HTML-safe regexp.
        line.html(line.html().replace(replace_re, function (str) {
          return _self.wrapInHighlight(str);
        }));

        // And callback to put in result list
        _self.addSearchResult({
          targetId: lineId,
          highlightedMatch: highlightedMatch
        });
      }
    });
  },

  addSearchResult: function(resultObj) {
    $(document).find("*[data-ohms-search-results]").append(
      "<li><a href='#' data-ohms-scroll-to-id='" + resultObj.targetId + "'>" + resultObj.highlightedMatch + "</a></li>"
    );
  },

  clearSearchResults: function() {
    $(document).find("*[data-ohms-search-results]").empty();
    $(document).find('.ohms-highlight').contents().unwrap();
  }
}

$(document).on("click", "*[data-ohms-scroll-to-id]", function(event) {
  event.preventDefault();

  var id = this.dataset.ohmsScrollToId;
  // without block:center, it ends up scrolling under our fixed navbar, gah!
  // this seems to be good enough.
  document.getElementById(id).scrollIntoView({behavior: "smooth", block: "center"});
});


window.Search = Search;
