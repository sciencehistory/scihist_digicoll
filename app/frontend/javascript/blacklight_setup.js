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
