// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, or any plugin's
// vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file. JavaScript code in this file should be added after the last require_* statement.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require rails-ujs
//



// Note do NOT to try require `bootstrap-sprockets`, while it used to work and be
// recommended by Blacklight, stopped being compatible with Blacklight in 7.22.0
// for mysterious reasons.
//= require bootstrap

//= require cocoon
//= require browse_everything

// Required by Blacklight
      // not currently using blacklight 'suggest' func which uses twitter typeahead.
      // twitter typeahead is a non maintained kind of mess, so we might try to
      // avoid it even if we wanted auto-suggest.
      //
      // Twitter Typeahead for autocomplete
      // require twitter/typeahead
//= require blacklight/blacklight

// For blacklight_range_limit built-in JS, if you don't want it you don't need
// this:
//= require 'blacklight_range_limit'

//= require_tree .



