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
  var navbarBottom = $(".now-playing-container").get(0).getBoundingClientRect().bottom;

  if (targetViewportXPosition <= navbarBottom) {
    window.scrollTo({top: window.scrollY - (navbarBottom - targetViewportXPosition), behavior: "smooth"});
  }
});
