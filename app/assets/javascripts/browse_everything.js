// browse_everything https://github.com/samvera/browse-everything
//
// * JS is at the moment only available via sprockets.
// * The standard way to include `require browse_everything` will also
//   include`bootstrap. We want to control bootstrap inclusion ourselves,
//   possibly via vite. So we include the sub-parts directly, excluding
//   bootstrap.
// * See https://github.com/samvera/browse-everything/issues/411

// browse_everything is currently only used on staff/admin pages, so at the moment
// we include this JS on the staff back-end.


//= require jquery.treetable
//= require browse_everything/behavior
