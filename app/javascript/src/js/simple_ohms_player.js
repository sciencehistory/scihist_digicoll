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

  // a SearchResults object or empty
  currentResults: undefined,

  // Returns 'result' objects, how do we make one of them?
  // context, tab id, id.
  //
  // looks through all objects that are .ohms-transcript-line,
  // that works for our DOM. Should we add a data- hook?
  //
  // Highlights every hit, results a list of result objects.
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

    return $(".ohms-transcript-line").map(function() {
      var line = $(this);

      var lineId = this.id;
      var match = line.text().match(find_re);

      if (match) {
        var highlightedMatch = match[1] + _self.wrapInHighlight(match[2]) + match[3];

        // Actually highlight in source HTML, using HTML-safe regexp.
        line.html(line.html().replace(replace_re, function (str) {
          return _self.wrapInHighlight(str);
        }));

        return {
          targetId: lineId,
          highlightedMatch: highlightedMatch
        }
      }
    }).get(); // plain array not jQuery object
  },

  clearSearchResults: function() {
    $(document).find("*[data-ohms-search-results]").empty();
    $(document).find('.ohms-highlight').contents().unwrap();
    this.currentResults = undefined;
  }

}

Search.SearchResults = function(domContainer, results) {
    this.domContainer = domContainer;
    this.results = results;

    this.resultsPerPage = 5;

    this.pageNumber = 1;
}

// First argument is optional page number, if passed in it is set as instance state.
Search.SearchResults.prototype.draw =  function(pageNumber) {
  if (pageNumber) { this.pageNumber = pageNumber; }

  var fromItem = ((this.pageNumber - 1) * this.resultsPerPage) + 1;
  var toItem = Math.min(this.pageNumber * this.resultsPerPage, this.results.length);
  var resultsSlice = this.results.slice(fromItem - 1, toItem);


  var html =  "<div class='ohms-search-results'>" +
    this.paginationHtml(fromItem, toItem) +
    "<ol start=" + fromItem + ">" +
      resultsSlice.map(function(resultObj) {
        return "<li><a href='#' data-ohms-scroll-to-id='" + resultObj.targetId + "'>" + resultObj.highlightedMatch + "</a></li>"
      }).join("\n") +
    "</ol>" +
  "</div>";

  $(this.domContainer).html(html);
};

Search.SearchResults.prototype.paginationHtml = function(fromItem, toItem) {
  if (this.resultsPerPage >= this.results.length ) {
    return "";
  }

  return "<div class='ohms-result-pagination'>" +
            "<span class='showing'>Showing <strong>" +  fromItem + "</strong> - <strong>" + toItem + "</strong> of <strong>" + this.results.length + "</strong></span> " +
            "<span class='nav'>" +
              '<div class="btn-group btn-group-sm" role="group" aria-label="Basic example">' +
                  this.prevButtonHtml() +
                  this.nextButtonHtml() +
              '</div>' +
            "</span>" +
          "</div>";
}

Search.SearchResults.prototype.prevButtonHtml = function() {
  return '<button type="button" class="btn btn-outline-secondary" title="Previous page" aria-label="Previous page" ' +
            ((this.pageNumber <= 1) ? " disabled " : ('data-ohms-page-link="' + (this.pageNumber - 1) + '"')) +
          '>' +
              '<i class="fa fa-chevron-left" aria-hidden="true"></i>' +
          '</button>';
}

Search.SearchResults.prototype.nextButtonHtml = function() {
  return '<button type="button" class="btn btn-outline-secondary" title="Next page" aria-label="Next page" ' +
            ((this.pageNumber * this.resultsPerPage >= this.results.length) ? " disabled " : ('data-ohms-page-link="' + (this.pageNumber + 1) + '"')) +
          '>' +
              '<i class="fa fa-chevron-right" aria-hidden="true"></i>' +
          '</button>';
}


$(document).on("click", "*[data-ohms-scroll-to-id]", function(event) {
  event.preventDefault();

  var id = this.dataset.ohmsScrollToId;
  // without block:center, it ends up scrolling under our fixed navbar, gah!
  // this seems to be good enough.
  document.getElementById(id).scrollIntoView({behavior: "smooth", block: "center"});
});

$(document).on("submit", "*[data-ohms-search-form]", function(event) {
  event.preventDefault();

  Search.clearSearchResults();

  var query = $(event.target).find("*[data-ohms-input-query]").val();

  Search.currentResults = new OhmsSearch.SearchResults(
    $("*[data-ohms-search-results]").get(0),
    Search.searchTranscript(query)
  );

  Search.currentResults.draw();
});

$(document).on("click", "*[data-ohms-page-link]", function(event) {
  event.preventDefault();

  var page = $(this).data("ohmsPageLink");

  Search.currentResults.draw(page);
});

$(document).on("click", "*[data-ohms-clear-search]", function(event) {
  event.preventDefault();

  $("*[data-ohms-input-query]").val("");
  Search.clearSearchResults();
});


window.OhmsSearch = Search;
