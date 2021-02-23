// After an accordion section change, sometimes the open section is scrolled out
// of the viewport. This can happen occasionally even in an 'ordinary' situation
// with bootstrap accordion, but our fixed navbar makes it even more likely that
// the open section is hidden behind the navbar.
//
// We detect that condition, and scroll to reveal it, after calculating
// the #ohmsAudioNavbar height to know how much space to leave.
//
// We also scroll if the target is off the BOTTOM of the page after opening,
// which can mainly happen if we switched to specific segment on page load due
// to #anchor.
//
// Only within an .ohms-index-container, not affecting all bootstrap collapse/accordions.
$(document).on("shown.bs.collapse", ".ohms-index-container", function(event) {
  var indexSection = $(event.target).closest(".ohms-index-point").get(0);

  if (!indexSection) { return; }

  var targetViewportXPosition = indexSection.getBoundingClientRect().top;
  var navbarHeight = $("#ohmsAudioNavbar").height();

  if (targetViewportXPosition <= navbarHeight || targetViewportXPosition > window.innerHeight) {
    window.scrollTo({top: window.scrollY - (navbarHeight - targetViewportXPosition), behavior: "smooth"});
  }
});
