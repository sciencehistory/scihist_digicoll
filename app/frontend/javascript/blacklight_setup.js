// While not doc'd very well, this seems to be the way to import all blacklight Javascript.

import 'blacklight-frontend';

// That, I think, is a file created at release-time that collects ALL of the blacklight JS modules.


// This could have also worked, same thing I think?
// import 'blacklight-frontend/app/assets/javascripts/blacklight/blacklight';



// We USED to be able to pick-and-choose just the ones we need -- we don't actually need all of them, because
// we don't use all BL parts.
//
// See some docs (not necessarily kept up to date) at https://github.com/projectblacklight/blacklight/wiki/Using-Webpacker-to-compile-javascript-assets
//
// And also see these other apps selectively importing in Blacklight 7:
//
//   * https://github.com/psu-libraries/psulib_blacklight/blob/451a8ab9e64eaed8b0000bda0300a4f28097f165/app/javascript/psulib_blacklight/index.js
//   * https://github.com/unt-libraries/discover/blob/3c02d22bda7ec3f9e1d2f71a49c3b7e662ef8758/app/webpacker/packs/base.js.erb
//
// As of Blacklight 8.0.1, that does not seem possible anymore. Should it be? Questions asked at:
//
// https://github.com/projectblacklight/blacklight/issues/3050




