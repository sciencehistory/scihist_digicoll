// Import all blacklight javascript, in BL 8 via a rollup derived combo file
// While not doc'd very well, this seems to be [the/a] way to import all blacklight Javascript.

import Blacklight from 'blacklight-frontend';


// We USED to be able to pick-and-choose just the ones we need -- we don't actually need all of them, because
// we don't use all BL parts.
//
// As of Blacklight 8, that is not seem possible anymore, but will be again in 9
//
// https://github.com/projectblacklight/blacklight/issues/3050
// We used to import only:

// import 'blacklight-frontend/app/javascript/blacklight/core';
//       // import 'blacklight-frontend/app/javascript/blacklight/bookmark_toggle';
//       // import 'blacklight-frontend/app/javascript/blacklight/button_focus';
//       // import 'blacklight-frontend/app/javascript/blacklight/checkbox_submit';
// import 'blacklight-frontend/app/javascript/blacklight/facet_load';
// import 'blacklight-frontend/app/javascript/blacklight/modal';
//       //import 'blacklight-frontend/app/javascript/blacklight/search_context';


import BlacklightRangeLimit from "blacklight-range-limit";
BlacklightRangeLimit.init({onLoadHandler: Blacklight.onLoad });


// Patch in some blacklight modal fixes

if (Blacklight.Modal.target()) {

  // Disable scrollbar on body when modal is open
  // https://github.com/projectblacklight/blacklight/pull

  Blacklight.Modal.target().addEventListener("show.blacklight.blacklight-modal", (event) => {
    // Turn off body scrolling
    Blacklight.Modal.originalBodyOverflow = document.body.style['overflow'];
    Blacklight.Modal.originalBodyPaddingRight = document.body.style['padding-right'];
    document.body.style["overflow"] = "hidden"
    document.body.style["padding-right"] = "0px"
  });

  Blacklight.Modal.target().addEventListener("hide.blacklight.blacklight-modal", (event) => {
    // Turn body scrolling back to what it was
    document.body.style["overflow"] = Blacklight.Modal.originalBodyOverflow;
    document.body.style["padding-right"] = Blacklight.Modal.originalBodyPaddingRight;
    Blacklight.Modal.originalBodyOverflow = undefined;
    Blacklight.Modal.originalBodyPaddingRight = undefined;
  });


  // Make click on background overlay close modal

  Blacklight.Modal.target().addEventListener("click", (event) => {
    if (event.target.matches(Blacklight.Modal.modalSelector)) {
      Blacklight.Modal.hide();
    }
  });

  // Make sure we catch html modal's own close (eg escape key), to trigger blacklight
  // hide cleanup, including restoration of scroll behavior!
  // https://github.com/sciencehistory/scihist_digicoll/issues/3049
  Blacklight.Modal.target().addEventListener("cancel", (event) => {
    // we can stop default behavior, we're going to close the dialog ourselves
    event.preventDefault();
    Blacklight.Modal.hide();
  });
}

