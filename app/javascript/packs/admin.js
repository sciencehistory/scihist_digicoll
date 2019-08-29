// Javascript which is used for our backend/admin/management interfaces,
// but not for public interfaces. Will be compiled/aggregated into a separate
// JS 'pack' file that is only loaded in admin layout.
//
// One reason for this is our 'admin' JS at least at present
// includes things not compatible with IE11 -- we consider
// it okay at present that management UI doesn't work on IE11, but we need public UI to.

import '../src/js/admin/member_sortable';
import '../src/js/admin/tab_selection_in_anchor';
import '../src/js/admin/simple_uppy_file_input';
import '../src/js/admin/uppy_dashboard.js';
import '../src/js/admin/qa_autocomplete.js';
