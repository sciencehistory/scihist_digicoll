// Assign global window.$ and window.jQuery becuase we mayhave  code that
// needs to access it like this, possibly some local code still.
//
// And also including code included via sprockets which can find it here.
import $ from 'jquery'
window.jQuery = window.$ = $


