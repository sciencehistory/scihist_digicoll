// Bookreader wants jQuery in global object
// We need to do it in a separate file so the window.* assignment happens
// after jquery import but before other book reader loading code happens

import $ from 'jquery';
window.jQuery = window.$ = $;
