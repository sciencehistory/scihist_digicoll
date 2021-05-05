// A "jump to text" button will scroll to portion of transcript matching current timecode
// in player. OR if you are in ToC tab, open/scroll to segment of ToC matching current timecode.

document.body.addEventListener("click", function (event) {
  if (event.target.matches("*[data-trigger='ohms-jump-to-text']")) {
    var player = document.querySelector("audio[data-role=ohms-audio-elem]");
    var timeCodeSeconds = player.currentTime;
    var activeTab = getActiveTab();

    if (activeTab.id == "ohTocTab") {
      var collapsible = findTocCollapsibleSection(timeCodeSeconds);
      if (collapsible) {
        if (collapsible.classList.contains("collapse")) {
          $(collapsible).collapse("show");
        }
        // And scroll to the
        scrollToElement(collapsible.closest(".card").querySelector(".card-header"));
      }
    } else if (activeTab) {
      // if we have anything else, jump to transcript point, activating
      // transcript tab first if needed.
      if (activeTab.id != "ohTranscriptTab") {
        $('*[data-toggle="tab"][href="#ohTranscript"]').tab("show");
      }

      var element = findTranscriptAnchor(timeCodeSeconds);
      if (element) {
        scrollToElement(element);
      }
    }
  }
});


function findTranscriptAnchor(timeInSeconds) {
  return findOhmsTimestampElementIncluding(timeInSeconds, "a")
}

function findOhmsTimestampElementIncluding(timeInSeconds, baseSelector) {
  var previousEl = undefined;
  for (element of document.querySelectorAll(baseSelector + "[data-ohms-timestamp-s]")) {
    if (element.getAttribute("data-ohms-timestamp-s") > timeInSeconds) {
      return previousEl;
    }
    previousEl = element;
  }
  return undefined;
}

// Returns an element that you can call boostrap element.collapse()
// on, for ToC section corresponding to timecode.
function findTocCollapsibleSection(timeInSeconds) {
  var button = findOhmsTimestampElementIncluding(timeInSeconds, "button");

  // need to find it's parent collapsible
  return button && button.closest("*[data-parent='#ohmsIndexAccordionParent']")
}

// What makes this slightly less than completely simple is allowing for
// the fixed navbar on top; built-in browser functions will often wind
// up scrolling it top of window, under navbar.
//
function scrollToElement(element) {
  var targetDocumentXPosition = element.getBoundingClientRect().top + window.scrollY;
  var navbarHeight = document.querySelector("#ohmsAudioNavbar").offsetHeight;

  window.scrollTo({top: (targetDocumentXPosition - navbarHeight)});
}

// returns dom element for tab (the button that triggers the tab, that you can
// call tab() on).
function getActiveTab() {
  var content = document.querySelector("#ohmsScrollable .tab-pane.active");
  return content && document.querySelector(`*[data-toggle="tab"][href="#${content.id}"]`);
}
