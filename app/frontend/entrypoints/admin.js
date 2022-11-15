// Javascript which is used for our backend/admin/management interfaces,
// but not for public interfaces. Will be compiled/aggregated into a separate
// JS 'pack' file that is only loaded in admin layout.
//
// One reason for this is our 'admin' JS at least at present
// includes things not compatible with IE11 -- we consider
// it okay at present that management UI doesn't work on IE11, but we need public UI to.

// browse_everything also has CSS, needs to come before our other local code cause others refer to it
import "../browse_everything/browse_everything.js"

import '../javascript/admin/member_sortable';
import '../javascript/admin/simple_uppy_file_input';
import '../javascript/admin/uppy_dashboard.js';
import '../javascript/admin/qa_autocomplete.js';
import '../javascript/admin/queue_status_submit.js';

import '../javascript/admin/tom_select.js' // has CSS
