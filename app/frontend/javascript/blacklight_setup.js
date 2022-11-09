// The Blacklight docs at
//    https://github.com/projectblacklight/blacklight/wiki/Using-Webpacker-to-compile-javascript-assets#installing-webpacker-in-blacklight
//
// Suggest importing ALL of BL JS with:
//
//      import 'blacklight-frontend/app/javascripts/blacklight/blacklight'
//
// BUT we instead take a picking-and-choosing approach to import only
// the BL JS we want.  This is mainluy to *avoid* importing `typeahead`,
// which at least in BL 7.x is a LOT of code (it brings in some big dependencies)
//
// It's possible we're still including other JS we don't actually use; on the other
// side, future versions of BL may include JS that we want but don't automatically
// get included without us realizing and editing here.
//
// While this picking-and-choosing apporach is not documented, other BL
// apps in the wild do it, eg:
//
//   * https://github.com/psu-libraries/psulib_blacklight/blob/451a8ab9e64eaed8b0000bda0300a4f28097f165/package.json
//   * https://github.com/unt-libraries/discover/blob/3c02d22bda7ec3f9e1d2f71a49c3b7e662ef8758/app/webpacker/packs/base.js.erb
//
// From all sub-parts at Blacklight 7.31.0
//

import 'blacklight-frontend/app/javascript/blacklight/core';
// import 'blacklight-frontend/app/javascript/blacklight/bookmark_toggle';
// import 'blacklight-frontend/app/javascript/blacklight/button_focus';
// import 'blacklight-frontend/app/javascript/blacklight/checkbox_submit';
import 'blacklight-frontend/app/javascript/blacklight/facet_load';
import 'blacklight-frontend/app/javascript/blacklight/modal';
//import 'blacklight-frontend/app/javascript/blacklight/search_context';
