// JS for our local custom OHMS player functionality.
//
// This is pretty much all about SEARCH over OHMS transcript and table of contents.
//
// JS support for features in transcript/table-of-contents themselves consists just of
// having links to skip to certain timecode on player, see play_at_timecode.js for that.
//
// ## CHALLENGES
//
// This JS has gotten kind of complex -- I am not an expert at figuring out how to structure
// JS for maintainability, or even figuring out what advanced JS features can be used in our
// webpacker pipeline while still supporting our browser targets. I have done my best.
//
// This is still JQuery-style Javascript, not trying to use any fancy front-end frameworks; didn't
// understand enough about them to pull them off and be sure of my decisions. Initially tried doing
// without JQuery with only plain old browser JS, but was too challenging for me too.
//
// Note that original/standard PHP OHMS viewer does searching server-side, and only uses
// JS to find the relevant passages to add highlighting to in the DOM.
//
// However, we are doing all searching client-side instead, actually searching through the
// DOM for hits. Seems to work out okay, but if it doesn't, say for performance reasons,
// we can always switch to server-side. We are also writing the code to do the searching ourselves,
// instead of trying to use a pre-built solution like https://markjs.io/, which would
// be another option.
//
// Some of our search code is BASED on what original ohms-viewer uses for highlighting. The
// ohms-viewer code seems to be located in https://github.com/uklibraries/ohms-viewer/blob/45e0ab6df2388ce4e9704c89ce16f4ece953e2de/js/toggleSwitch.js
//
// ## IMPLEMENTATION OVERVIEW
//
// First, we implement an object called `Search`, that has 'static' global functions and data for
// search behavior, called on the global constant, for example `Search.wrapInHighlight(string`,
// or `Search.resultsMode()` or `Search.drawResults()`.
//
// Secondly, we implement a more class-based type called `SearchResults`, an object of which
// represents a single set of search results for either table-of-contents section (often called
// "index" in code, as per original OHMS), or transcript section.
//
// It is initialized with a dom element that is the target for displaying search results,
// a list of result objects, either "transcript" or "index" as a mode.
//
//     new Search.SearchResults($("*[data-ohms-search-results]").get(0), array_of_results, "transcript");
//
// Thirdly and finally, we have some JQuery event handlers to wire up interactive behavior for search,
// including executing the search, and letting tab switches control which search mode we are in,
// index or transcript.



var Search = {};


// A function to take a string and turn it into a regexp for that literal, escaping
// any regexp special chars.
//
// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Regular_Expressions
Search.escapeRegExp = function(string) {
  return string.replace(/[.*+\-?^${}()|[\]\\]/g, '\\$&'); // $& means the whole matched string
};

// Just wraps text in span.ohms-highlight. No escaping is done, input
// can include HTML, it will be presered.
Search.wrapInHighlight =  function(match) {
  return "<span class=\"ohms-highlight\">" + match + "</span>";
};

// After a search, we have a SearchResults object for Transcript, one
// for Index (ToC); and a resultsMode state that should be either 'transcript',
// or 'index' to tell us which is currently being displayed.
Search.currentTranscriptResults = undefined;
Search.currentIndexResults      = undefined;


// Returns "index" or "transcript" depending on which set of results we are currently
// displaying. Lazily calculates it if needed.
Search.resultsMode = function() {
  if (this.resultsModeVal == undefined) {
    if ($("#ohToc").length > 0) {
      this.resultsModeVal = "index";
    } else {
      this.resultsModeVal = "transcript";
    }
  }

  return this.resultsModeVal;
};

// Returns a SearchResults object (see below) for the set of
// results we are currently dispaying (`currentIndexResults` or `currentTranscriptResults`)
Search.currentResults = function() {
  // No idea why we need to say 'Search' instead of 'self' here.
  if (Search.resultsMode() == "index") {
    return Search.currentIndexResults;
  } else {
    return Search.currentTranscriptResults;
  }
};

// Draws current results for current results mode (transcript or index) -- makes
// the search results show up on screen matching current state.
Search.drawResults = function(resultIndex) {
  self.currentResults().draw(resultIndex);
};

// Returns a regular expression as a STRING (so it can be embedded inside other regexps),
// meant for searching the DOM for search query. Borrowed/modified from ohms-viewer code,
//
// I think they are meant to avoid matching on HTML tags, so we can search and replace
// the DOM to add highlight tags?
Search.regexpStrForSearch = function(query) {
  if (/^((?!chrome|android).)*safari/i.test(navigator.userAgent) || navigator.userAgent.search("Firefox")) {
      return "(?![^<>]*(([\/\"']|]]|\b)>))(" + this.escapeRegExp(query) + ')';
  } else {
      return '(?<!</?[^>]*|&[^;]*)(' + this.escapeRegExp(query) + ')';
  }
};

// Returns array of 'result' objects, how do we standardize what that is?
// context, tab id, id.
//
// looks through all objects that are .ohms-transcript-line,
// that works for our DOM. Should we add a data- hook?
//
// Highlights every hit, results a list of result objects.
Search.searchTranscript = function(query) {
  var _self = this;

  var reStr = _self.regexpStrForSearch(query);

  // one we'll use for replacing with highlight. Used on HTML.
  var replace_re = new RegExp(reStr, 'gi');
  // one we'll use for capturing with some surrounding context, up to one word before and 4 after.
  // Used on pure text. Capture groups will be:
  // 0 (actual match, not capture group): result in context with before and after
  // 1: before match
  // 2: match
  // 3: after match
  var find_re = new RegExp("((?:\\S*\\s+\\S*){0,1})(" + query + ")((?:\\s*\\S+\\s*){0,4})", "gi")

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
        tabId: "ohTranscriptTab",
        targetId: lineId,
        highlightedMatch: highlightedMatch
      }
    }
  }).get(); // plain array not jQuery object
};

// Like searchTranscript, but searches the Table Of Contents "index" content.
//
// Returns array of "result" objects.
//
// Highlights hits in index results.
Search.searchIndex = function(query) {
  var _self = this;

  var reStr = new RegExp(_self.regexpStrForSearch(query), "gi");

  return $(".ohms-index-point").map(function() {
    var section = $(this);

    var targetId = section.attr("id");
    if (! targetId) { throw "can't record ohms search without finding a dom id " + section.get(0) }

    var replacementMade = false;
    var original = section.html();
    var replacedContent = original.replace(reStr, function(str) {
      replacementMade = true;
      return _self.wrapInHighlight(str);
    });

    if (replacementMade) {
      // there was a hit, so, highlight and include result

      section.html(replacedContent);

      return {
        tabId: 'ohIndexTab',
        targetId: targetId
      };
    }
  }).get() // plain array not jQuery object
};

// Clears all search results state, restores to initial condition with no search
// execcuted.
Search.clearSearchResults = function() {
  $(document).find("*[data-ohms-hitcount]").empty();
  $(document).find("*[data-ohms-search-results]").empty();
  $(document).find('.ohms-highlight').contents().unwrap();
  this.currentTranscriptResults = undefined;
  this.currentIndexResults = undefined;
};

// Scrolls browser to show domID passed in.
//
// While it would be lovely to just use built-in scrollIntoView, we need to take
// care of a few things that doesn't:
//
//   * Avoid fixed navbar on top, we don't want to scroll so the thing we want
//     to show is behind the navbar.
//
//   * If id is in a tab that isn't currently visible, switch to that tab.
//
//   * If id is in a bootstrap collapsed that isn't currently expanded, expand it.
//     (intended for Table of Contents section)
//
// Second optional argument is either "smooth" or "auto", with "auto" being the
// default. As in HTML5 scroll functions which it will be passed to, "smooth"
// will do a visible smooth scroll, "auto" just jumps to position.
Search.scrollToId = function(domID, scrollBehavior) {
  if (scrollBehavior == undefined) {
    scrollBehavior = "smooth";
  }

  // without block:center, it ends up scrolling under our fixed navbar, gah!
  // this seems to be good enough.
  var element = document.getElementById(domID);

  // If it's in a tab, and the tab isn't currently shown, make it shown
  var tabPane = $(element).closest(".tab-pane");
  if (tabPane) {
    // annoyingly, have to get the actual tab link that corresponds to
    // the pane
    var tab = $(".nav-link[href='#" + tabPane.attr("id") + "']");
    tab.tab("show");
  }

  // If our target element CONTAINS a bootstrap collapsible that is collapsed,
  // show it. This is intended for our ToC accordion.
  var collapsible = $(element).find(".collapse");
  if (collapsible && ! collapsible.hasClass("show")) {
    collapsible.collapse("show");
  }

  var elTop = $(element).offset().top;
  var navbarHeight = $("#ohmsAudioNavbar").height();

  window.scrollTo({top: elTop - navbarHeight, behavior: scrollBehavior});
};

// Execute a search, in response to a search submit. Find transcript and index
// results, set search results state, draw search results on screen.
Search.onSearchSubmit = function(event) {
  event.preventDefault();

  Search.clearSearchResults();

  var query = $(event.target).find("*[data-ohms-input-query]").val();

  if (query == "") {
    return;
  }

  var transcriptResults = Search.searchTranscript(query);
  Search.currentTranscriptResults = new Search.SearchResults(
    $("*[data-ohms-search-results]").get(0),
    transcriptResults,
    "transcript"
  );
  $("*[data-ohms-hitcount='transcript']").html('<span class="badge badge-pill badge-danger">' + transcriptResults.length + '</span>');

  var indexResults = Search.searchIndex(query);
  Search.currentIndexResults = new Search.SearchResults(
    $("*[data-ohms-search-results]").get(0),
    indexResults,
    "index"
  );
  $("*[data-ohms-hitcount='index']").html('<span class="badge badge-pill badge-danger">' + indexResults.length + '</span>');

  Search.currentResults().draw();
  Search.currentResults().scrollToCurrentResult();
};



/*

   Search.SearchResults object, encapsulates a single result set (either transcript or index),
   and logic for for drawing the search results area.

   Also has a method scrollToCurrentResult which will scroll page to current result,
   switching to tabs etc if needed, using functionality in Search object.

       var results = new Search.SearchResults($("*[data-ohms-search-results]").get(0), array_of_results, "transcript");
       results.draw(); // draw results on screen
       results.draw(12); // switch to displaying result 12 and draw
       results.scrollToCurrentResult();

 */

// Initialized with a dom element that is the container for rendering search results,
// a list of result objects, either "transcript" or "index" as a mode.
Search.SearchResults = function(domContainer, results, mode) {
    this.domContainer = domContainer;
    this.results = results;
    this.mode = mode;

    if (this.mode != "index" && this.mode != "transcript") {
      throw "third 'mode' arg must be 'index' or 'transcript'";
    }

    this.currentResultIndex = 1; // 1-based index into results
}

// First argument is optional currentResultIndex, if passed in it is set as instance state.
//
// currentResultIndex is jumped to
Search.SearchResults.prototype.draw =  function(currentResultIndex) {
  if (currentResultIndex) { this.currentResultIndex = currentResultIndex; }

  if (this.results.length == 0) {
    $(this.domContainer).html(
      "<div class='ohms-search-results'>" +
        "<span class='search-mode'>" + this.modeName() +" — </span> " +
        "<span class='ohms-no-results'>No results.</span>" +
      "</div>"
    );
    return;
  }


  var html =  "<div class='ohms-search-results'>" +
    this.navigationHtml() +
  "</div>";

  $(this.domContainer).html(html);
};

Search.SearchResults.prototype.scrollToCurrentResult = function() {
  // currentResultIndex is 1-based
  var result = this.results[this.currentResultIndex - 1];
  Search.scrollToId(result.targetId);
}

Search.SearchResults.prototype.navigationHtml = function() {

  return "<div class='ohms-result-navigation'>" +
            "<span>" +
              "<span class='search-mode'>" + this.modeName() +" — </span> " +
              "<a href='#' data-trigger='ohms-search-goto-current-result' class='showing'>" + this.currentResultIndex + " / " + this.results.length + "</a> " +
            "</span>" +
            "<span class='nav'>" +
              '<div class="btn-group btn-group-sm" role="group" aria-label="Basic example">' +
                  this.prevButtonHtml() +
                  this.nextButtonHtml() +
              '</div>' +
            "</span>" +
          "</div>";
}

// human readable mode name. "index" is actually Table of Contents.
Search.SearchResults.prototype.modeName = function() {
  if (this.mode == "transcript") {
    return "Transcript";
  } else if (this.mode == "index") {
    return "Table of Contents";
  }
}

Search.SearchResults.prototype.prevButtonHtml = function() {
  var prevIndex = this.currentResultIndex - 1;
  if (prevIndex <= 0) {
    prevIndex = this.results.length;
  }

  return '<button type="button" class="btn btn-outline-secondary" title="Previous result" aria-label="Previous result" ' +
            'data-ohms-search-result-index="' + prevIndex + '"' +
          '>' +
              '<i class="fa fa-chevron-left" aria-hidden="true"></i>' +
          '</button>';
}

Search.SearchResults.prototype.nextButtonHtml = function() {
  var nextIndex = this.currentResultIndex + 1;
  if (nextIndex > this.results.length) {
    nextIndex = 1;
  }

  return '<button type="button" class="btn btn-outline-secondary" title="Next result" aria-label="Next result" ' +
            'data-ohms-search-result-index="' + nextIndex + '"' +
          '>' +
              '<i class="fa fa-chevron-right" aria-hidden="true"></i>' +
          '</button>';
}


/*

  EVENT HANDLERS

*/


// Submitting the search form wil do a search
$(document).on("submit", "*[data-ohms-search-form]", function(event) {
  Search.onSearchSubmit(event);
});


// Clicking on next or previous button will scroll to that result, and
// re-draw the search results to show current result.
$(document).on("click", "*[data-ohms-search-result-index]", function(event) {
  event.preventDefault();

  var resultIndex = $(this).data("ohmsSearchResultIndex");

  Search.currentResults().draw(resultIndex);
  Search.currentResults().scrollToCurrentResult();
});



// Clickig on the "X / Y" current result readout should scroll to current result
$(document).on("click", "*[data-trigger='ohms-search-goto-current-result']", function(event) {
  event.preventDefault();
  Search.currentResults().scrollToCurrentResult();
});


// Clicking on "x" clear search button will clear all search results
// and restore to initial state.
$(document).on("click", "*[data-ohms-clear-search]", function(event) {
  event.preventDefault();

  $("*[data-ohms-input-query]").val("");
  Search.clearSearchResults();
});


// After a tab switch, we need to switch the search mode if it was index or transcript
// tab.
$(document).on("shown.bs.tab", ".work-show-audio", function(event) {
  if (event.target.id == "ohTocTab" && Search.resultsMode() != "index") {
    Search.resultsModeVal = "index";
    if (Search.currentResults()) {
      Search.currentResults().draw();
    }
  } else if (event.target.id == "ohTranscriptTab" && Search.resultsMode() != "transcript") {
    Search.resultsModeVal = "transcript";
    if (Search.currentResults()) {
      Search.currentResults().draw();
    }
  }
});


//window.OhmsSearch = Search;
