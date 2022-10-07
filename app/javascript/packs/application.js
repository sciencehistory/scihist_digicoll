/* eslint no-console:0 */
// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/javascript and only use these pack files to reference
// that code so it'll be compiled.
//
// To reference this file, add <%= javascript_pack_tag 'application' %> to the appropriate
// layout file, like app/views/layouts/application.html.erb

// fetch polyfill for IE11, used by viewer, on-demand downlaods, and other local code.
import 'whatwg-fetch';
// The whatwg-fetch polyfill requires a promise polyfill too, for browsers that don't
// have promises, and IE11 is one, so.
import 'promise-polyfill/src/polyfill';

import "../src/js/responsive-tabs/responsive-tabs.js"

import '../src/js/init_popovers.js';
import '../src/js/accept_cookies_banner.js';
import '../src/js/scihist_search_slideout.js';
import '../src/js/scihist_on_demand_downloader.js';
import '../src/js/scihist_viewer.js';
import '../src/js/custom_google_analytics_events.js';
import '../src/js/cart_control.js';
import '../src/js/date_range_render_workaround.js';
import '../src/js/tab_selection_in_anchor';


// Generic tooltips
import '../src/js/bootstrap_tooltips_activate';
// and special OHMS footnotes tooltips
import '../src/js/ohms_footnotes.js';

import '../src/js/audio/play_at_timecode.js';
import '../src/js/audio/ohms_search.js';
import '../src/js/audio/accordion_open_on_screen.js';
import '../src/js/audio/navbar_tabs.js';
import "../src/js/audio/timecode_in_anchor.js";
import "../src/js/audio/share_link.js";
import '../src/js/audio/jump_to_text.js';
import "../src/js/audio/clipboard_copy_input.js";
import "../src/js/video_player.js";
import "../src/js/survey_widget.js";
