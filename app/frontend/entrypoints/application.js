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


// We're still using rails-ujs for now. Rails-ujs 6.x will auto-start itself on import.
import Rails from '@rails/ujs';

import '../javascript/jquery_setup.js'
import '../javascript/bootstrap_setup.js'

// used by kithe, for forms with add/remove fields
import "@nathanvda/cocoon";

import '../javascript/blacklight_setup.js';

import "../javascript/responsive-tabs/responsive-tabs.js"

import '../javascript/init_popovers.js';
import '../javascript/accept_cookies_banner.js';
import '../javascript/scihist_search_slideout.js';
import '../javascript/scihist_on_demand_downloader.js';
import '../javascript/scihist_viewer.js';
import '../javascript/custom_google_analytics_events.js';
import '../javascript/cart_control.js';
import '../javascript/date_range_render_workaround.js';
import '../javascript/tab_selection_in_anchor';
import '..//javascript/survey_widget.js';

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
