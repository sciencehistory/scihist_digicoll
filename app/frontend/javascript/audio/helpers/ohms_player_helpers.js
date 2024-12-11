/*

  Some utility functions for dealing with our OHMS player, in particular to jumping to
  particular points in OHMS transcript or Toc.

  Exported via ESM.

  You can import in two ways using standard ESM:

      import * as OhmsHelpers from './helpers/ohms_player_helpers.js';
      # to then call eg:
      OhmsHelpers.findTranscriptAnchor(1212);

      # OR

      import {findTranscriptAndhor, findTocCollapsibleSection} from './helpers/ohms_player_helpers.js'
      # to then call them as top-level functions
      findTransriptAnchor(1212);

As we interact with Bootstrap 4 Javascript in here, it does include some JQuery assumed
to be available. We try to avoid JQuery except for that.
 */

import * as bootstrap from 'bootstrap';

// Does not switch to tab, assumes ToC tab is open.
export function gotoTocSegmentAtTimecode(timeinSeconds) {
  var collapsible = findTocCollapsibleSection(timeinSeconds);
  if (collapsible) {
    goToTocCollapsible(collapsible);
  }
}

export function gotoTranscriptTimecode(timeInSeconds) {
  var element = findTranscriptAnchor(timeInSeconds);
  if (element) {
    scrollToElement(element);
  }
}

// Returns the <a> element from OHMS transcript that corresponds to best timecode
// link for timeInSeconds. For finding place in transcript corresponding to seconds.
export function findTranscriptAnchor(timeInSeconds) {
  return findOhmsTimestampElementIncluding(timeInSeconds, "#ohTranscript a")
}


// Returns a ToC that corresponds to best timecode
// link for timeInSeconds. That is, the segment that includes timeInseconds.
//
// Returns a div element that has bootstrap collapsible(), which you can call
// element.collapse() on, for the ToC section corresponding to timecode.
export function findTocCollapsibleSection(timeInSeconds) {
  var button = findOhmsTimestampElementIncluding(timeInSeconds, "#ohToc a");

  // need to find it's parent collapsible
  return button && button.closest("*[data-parent='#ohmsIndexAccordionParent']")
}


// Pass in a bootstrap collapsible() element, such as returned by findTocCollapsibleSection.
//
// We will make sure that section is EXPANDED, and then SCROLL to it.
export function goToTocCollapsible(collapsible) {
  var elementScrollTarget = collapsible.closest(".card").querySelector(".card-header");

  if (collapsible.classList.contains("collapse")) {
    bootstrap.Collapse.getOrCreateInstance(collapsible).show();

    // We have to wait until it's done being shown to scroll to it, to make
    // sure we're scrolling to correct place.
    collapsible.addEventListener('shown.bs.collapse', () => {
      scrollToElement(elementScrollTarget);
    }, {
      once: true,
    });
  } else {
    scrollToElement(elementScrollTarget);
  }
}


// Utility functions used by other fucntions in here. Finds an element with data-ohms-timestamp-s
// just less than timeInSeconds passed in, but you also pass in a baseSelector, what
// kind of element/selector with data-ohms-timestamp-s
//
// Works with second reslution only, avoid possible bugs with data-ohms-timestamp
// being different resolution than timeInSeconds, both are normalized to integer seconds.
export function findOhmsTimestampElementIncluding(timeInSeconds, baseSelector) {
  var elements = document.querySelectorAll(baseSelector + "[data-ohms-timestamp-s]");

  var previousEl = undefined;
  for (var element of elements) {
    // if we've found one PAST our timecode -- then the last one we found
    // is the segment containing our timecode.
    if (Math.trunc(element.getAttribute("data-ohms-timestamp-s")) > Math.trunc(timeInSeconds)) {
      // if previousEl is empty, our timecode may have been BEFORE the first element, just
      // do the first element, if we have one.
      return previousEl ? previousEl : elements[0]
    }
    previousEl = element;
  }

  // in case it's in last segment, need to return it here.
  // This may also return last segment for weird non-matches.
  return previousEl;
}

// What makes this slightly less than completely simple is allowing for
// the fixed navbar on top; built-in browser functions will often wind
// up scrolling it top of window, under navbar.
//
export function scrollToElement(element) {
  var targetDocumentXPosition = element.getBoundingClientRect().top + window.scrollY;
  var navbarHeight = document.querySelector("#ohmsAudioNavbar").offsetHeight;

  window.scrollTo({top: (targetDocumentXPosition - navbarHeight)});
}

// returns dom element for tab (the button that triggers the tab, that you can
// call tab() on).
export function getActiveTab() {
  var content = document.querySelector("#ohmsScrollable .tab-pane.active");
  return content && document.querySelector(`*[data-bs-toggle="tab"][href="#${content.id}"]`);
}
