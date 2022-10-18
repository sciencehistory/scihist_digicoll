// This is a SPROCCKETS manifest file that'll be compiled into an application.js
//
// It can include files via sprockets `//= require` directives in JS comments,
// below.
//
// Our sciencehistory app generally tries to avoid using sprockets for JS now, we
// use vite. This *only* includes assets which cannot be conveniently included via
// vite, for instance from dependencies that *only* provide their assets in manner
// for sprockets inclusion.
//
// This will produce a secondary `application.js` included via rails
// `javascript_include_tag`. For bulk of our JS, see vite stuff
// at ./app/frontend


// browse_everything https://github.com/samvera/browse-everything
//
// * JS is at the moment only available via sprockets.
// * The standard way to include `require browse_everything` will also
//   include`bootstrap. We want to control bootstrap inclusion ourselves,
//   possibly via vite. So we include the sub-parts directly, excluding
//   bootstrap.
// * See https://github.com/samvera/browse-everything/issues/411
//
//= require jquery.treetable
//= require browse_everything/behavior



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



