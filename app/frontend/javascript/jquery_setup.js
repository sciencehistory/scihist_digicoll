// Assign global window.$ and window.jQuery becuase we have plenty of code that
// needs to access it like this, including Bootstrap 4, other dependencies,
// possibly some local code still.
//
// And also including code included via sprockets which can find it here.
import $ from 'jquery'
window.jQuery = window.$ = $


// Bootstrap 4 also needs Popper, and needs it installed in window.Popper
import Popper from 'popper.js';
window.Popper = Popper;
