// JS we need for our local custom OHMS player func.
//
// Yeah, we'll use JQuery, sorry.
//
// TODO: put a `id` on .audio-navbar to use that instead.
// More docs.
// Separate data-ohms-timestamp-s into separate file?
// A test.

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

  tabScrollPositions: {},

  wrapInHighlight: function(match) {
    return "<span class=\"ohms-highlight\">" + match + "</span>";
  },

  // After a search, we have a SearchResults object for Transcript, one
  // for Index (ToC); and a resultsMode state that should be either 'transcript',
  // or 'index' to tell us which is currently being displayed.

  currentTranscriptResults: undefined,

  currentIndexResults: undefined,

  resultsMode: function() {
    if (this.resultsModeVal == undefined) {
      if ($("#ohToc").length > 0) {
        this.resultsModeVal = "index";
      } else {
        this.resultsModeVal = "transcript";
      }
    }

    return this.resultsModeVal;
  },

  currentResults: function() {
    // No idea why we need to say 'Search' instead of 'self' here.
    if (Search.resultsMode() == "index") {
      return Search.currentIndexResults;
    } else {
      return Search.currentTranscriptResults;
    }
  },

  drawResults: function(resultIndex) {
    self.currentResults().draw(resultIndex);
  },

  // Returns a regular expression as a STRING (so it can be embedded inside other regexps),
  // meant for searching the DOM for search query. Borrowed/modified from ohms-viewer code,
  //
  // I think they are meant to avoid matching on HTML tags, so we can search and replace
  // the DOM to add highlight tags?
  regexpStrForSearch: function(query) {
    if (/^((?!chrome|android).)*safari/i.test(navigator.userAgent) || navigator.userAgent.search("Firefox")) {
        return "(?![^<>]*(([\/\"']|]]|\b)>))(" + escapeRegExp(query) + ')';
    } else {
        return '(?<!</?[^>]*|&[^;]*)(' + escapeRegExp(query) + ')';
    }
  },

  // Returns array of 'result' objects, how do we standardize what that is?
  // context, tab id, id.
  //
  // looks through all objects that are .ohms-transcript-line,
  // that works for our DOM. Should we add a data- hook?
  //
  // Highlights every hit, results a list of result objects.
  searchTranscript: function(query) {
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
  },

  // Like searchTranscript, but searches the Table Of Contents "index" content.
  //
  // Returns array of "result" objects.
  //
  // Highlights hits in index results.
  searchIndex: function(query) {
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
  },

  clearSearchResults: function() {
    $(document).find("*[data-ohms-hitcount]").empty();
    $(document).find("*[data-ohms-search-results]").empty();
    $(document).find('.ohms-highlight').contents().unwrap();
    this.currentTranscriptResults = undefined;
    this.currentIndexResults = undefined;
  },

  // It would be lovely to just use built-in scrollIntoView, but we have
  // to scroll around the fixed navbar on top, so we end up using
  // some hacky jQuery stuff.
  //
  // Also importantly:
  // * switches to a containing tab if necessary
  // * Opens a containing bootstrap collapse if necessary (eg for Table of Contents/index section)
  scrollToId: function(domID, scrollBehavior) {
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
    var navbarHeight = $(".audio-navbar").height();

    window.scrollTo({top: elTop - navbarHeight, behavior: scrollBehavior});
  },

  onSearchSubmit: function(event) {
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
  }
}

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


$(document).on("submit", "*[data-ohms-search-form]", function(event) {
  Search.onSearchSubmit(event);
});

$(document).on("click", "*[data-ohms-search-result-index]", function(event) {
  event.preventDefault();

  var resultIndex = $(this).data("ohmsSearchResultIndex");

  Search.currentResults().draw(resultIndex);
  Search.currentResults().scrollToCurrentResult();
});

$(document).on("click", "*[data-ohms-clear-search]", function(event) {
  event.preventDefault();

  $("*[data-ohms-input-query]").val("");
  Search.clearSearchResults();
});

// After an accordion section change, sometimes the open section is scrolled out
// of the viewport. This can happen occasionally even in an 'ordinary' situation
// with bootstrap accordion, but our fixed navbar makes it even more likely that
// the open section is hidden behind the navbar.
//
// We detect that condition, and scroll to reveal it. Only within
// an .ohms-index-container, not affecting all bootstrap collapse/accordions.
$(document).on("shown.bs.collapse", ".ohms-index-container", function(event) {
  var indexSection = $(event.target).closest(".ohms-index-point").get(0);

  if (!indexSection) { return; }

  var targetViewportXPosition = indexSection.getBoundingClientRect().top;
  var navbarHeight = $(".audio-navbar").height();

  if (targetViewportXPosition <= navbarHeight) {
    window.scrollTo({top: window.scrollY - (navbarHeight - targetViewportXPosition), behavior: "smooth"});
  }
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

// On small screens, our tab bar can scroll, with some tabs off screen.
// Make sure a selected tab is fully on screen, in line with Material Design
// tab UI recommendations. We can use simple built into browser HTML5 scrollIntoView.
// If the thing is already fully in view -- including on large screens -- we're hoping it's
// a no-op.
$(document).on("shown.bs.tab", ".work-show-audio", function(event) {
  var tabElement = document.getElementById(event.target.id);
  tabElement.scrollIntoView({block: "nearest", inline: "nearest"});
});


// Clickig on the "X / Y" current result readout should scroll to current result
$(document).on("click", "*[data-trigger='ohms-search-goto-current-result']", function(event) {
  event.preventDefault();
  Search.currentResults().scrollToCurrentResult();
});



// Maintain scroll positions on tabs, kinda hacky
$(document).on("hide.bs.tab", ".work-show-audio", function(event) {

  // save scroll position, only if navbar is currently fixed to top due to scroll
  var navbarIsFixed = (document.getElementsByClassName("audio-navbar")[0].getBoundingClientRect().top == 0);

  if (navbarIsFixed) {
    Search.tabScrollPositions[event.target.id] = window.scrollY;
  } else {
    Search.tabScrollPositions[event.target.id] = undefined;
  }
});
$(document).on("shown.bs.tab", ".work-show-audio", function(event) {
  // restore scroll position, or move to a reasonable starting point if first time on this tab.

  var navbarIsFixed = (document.getElementsByClassName("audio-navbar")[0].getBoundingClientRect().top == 0);
  var saved = Search.tabScrollPositions[event.target.id];

  if (saved) {
    window.scrollTo({top: saved})
  } else if (! navbarIsFixed) {
    // navbar isn't fixed to top anyway, don't worry about it, too weird if we try.
    return;
  } else {
    // we don't have a saved position, but we're in position with fixed navbar at
    // top of page -- move to top of fixed navbar at top of page in new tab.

    // It's actually kind of hard to get the browsers to scorll to this position,
    // this kind of hack seems to work, in this situation:

    $(".audio-navbar").get(0).scrollIntoView({behavior: "auto", block: "end"});
    $(".audio-navbar").get(0).scrollIntoView({behavior: "auto", block: "start"});
  }
});



window.OhmsSearch = Search;
