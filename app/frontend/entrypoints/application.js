// To see this message, add the following to the `<head>` section in your
// views/layouts/application.html.erb
//
//    <%= vite_client_tag %>
//    <%= vite_javascript_tag 'application' %>
console.log('Vite ⚡️ Rails')

// If using a TypeScript entrypoint file:
//     <%= vite_typescript_tag 'application' %>
//
// If you want to use .jsx or .tsx, add the extension:
//     <%= vite_javascript_tag 'application.jsx' %>

console.log('Visit the guide for more information: ', 'https://vite-ruby.netlify.app/guide/rails')

// Example: Load Rails libraries in Vite.
//
// import * as Turbo from '@hotwired/turbo'
// Turbo.start()
//
// import ActiveStorage from '@rails/activestorage'
// ActiveStorage.start()
//
// // Import all channels.
// const channels = import.meta.globEager('./**/*_channel.js')

// Example: Import a stylesheet in app/frontend/index.css
// import '~/index.css'





import '../javascript/jquery_setup.js'
import "bootstrap";

// We're still using rails-ujs for now.
//
// This needs to be imported AFTER jquery is set up so it will properly
// patch jQuery.ajax with CSRF token, although it's not supposed to be this way,
// and strangely this order is only required in vite dev and not vite build.
//
// Explicit `Rails.start()` is really supposed to be needed, but we are finding
// we DO need it in `vite dev` mode, but do NOT in vite prodution mode, where
// it was leading to double-load of rails-ujs. We're not sure what's going on,
// and am ashamed that we're just going to hack it out with a conditional
// like this.
//
// https://github.com/rails/rails/blob/v7.0.4.1/actionview/app/assets/javascripts/rails-ujs/start.coffee#L22
import Rails from '@rails/ujs';
if (! window._rails_loaded) {
  console.log("scihist_digicoll: manually starting rails-ujs because it was not auto-started");
  Rails.start();
}


// used by kithe, for forms with add/remove fields
import "@nathanvda/cocoon";

import '../javascript/blacklight_setup.js';

import "../javascript/responsive-tabs/responsive-tabs.js"

import '../javascript/init_popovers.js';
import '../javascript/scihist_search_slideout.js';
import '../javascript/scihist_on_demand_downloader.js';
import '../javascript/scihist_viewer.js';
import '../javascript/custom_google_analytics_4_events.js';
import '../javascript/cart_control.js';
import '../javascript/date_range_render_workaround.js';
import '../javascript/tab_selection_in_anchor';

// Generic tooltips
import '../javascript/bootstrap_tooltips_activate';
// and special OHMS footnotes tooltips
import '../javascript/ohms_footnotes.js';

import '../javascript/audio/play_at_timecode.js';
import '../javascript/audio/ohms_search.js';
import '../javascript/audio/accordion_open_on_screen.js';
import '../javascript/audio/navbar_tabs.js';
import "../javascript/audio/timecode_in_anchor.js";
import "../javascript/audio/share_link.js";
import '../javascript/audio/jump_to_text.js';
import "../javascript/audio/clipboard_copy_input.js";
import "../javascript/video_player.js";

import "../javascript/main_nav_collapse_toggle.js";
import "../javascript/lazy_member_images.js"
import "../javascript/transcript_toggle.js"
