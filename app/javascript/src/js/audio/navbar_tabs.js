// On small screens, our tab bar can scroll, with some tabs off screen.
// Make sure a selected tab is fully on screen, in line with Material Design
// tab UI recommendations. We can use simple built into browser HTML5 scrollIntoView.
// If the thing is already fully in view -- including on large screens -- we're hoping it's
// a no-op.
$(document).on("shown.bs.tab", ".work-show-audio", function(event) {
  var tabElement = document.getElementById(event.target.id);
  tabElement.scrollIntoView({block: "nearest", inline: "nearest"});
});


// Maintain scroll positions on tabs, kinda hacky.

// Will hold scrollY positions for each tab,
var tabScrollPositions = {};


// When a tab is hidden, store it's scroll position, so can be restored when it's switched back.
$(document).on("hide.bs.tab", ".work-show-audio", function(event) {

  // save scroll position, only if navbar is currently fixed to top due to scroll
  var navbarIsFixed = (document.getElementById("ohmsAudioNavbar").getBoundingClientRect().top == 0);

  if (navbarIsFixed) {
    tabScrollPositions[event.target.id] = window.scrollY;
  } else {
    tabScrollPositions[event.target.id] = undefined;
  }
});


// Restore tab position on a tab when we switch back to it, or else try to get
// us at the "top" of the tab, so you don't wind up looking at the footer on a short tab.
// A bit hard to get right.
$(document).on("shown.bs.tab", ".work-show-audio", function(event) {
  // restore scroll position, or move to a reasonable starting point if first time on this tab.

  var navbarIsFixed = (document.getElementById("ohmsAudioNavbar").getBoundingClientRect().top == 0);
  var saved = tabScrollPositions[event.target.id];

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

    document.getElementById("ohmsAudioNavbar").get(0).scrollIntoView({behavior: "auto", block: "end"});
    document.getElementById("ohmsAudioNavbar").get(0).scrollIntoView({behavior: "auto", block: "start"});
  }
});
