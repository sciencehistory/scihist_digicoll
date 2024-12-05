// This turns on all generic Bootstrap tooltips.
// Note also app/javascript/src/js/ohms_footnotes.js, used exclusively
// to show hover-over citations on footnote references in
// OHMS  transcripts.
//
// https://getbootstrap.com/docs/5.0/components/tooltips/#example-enable-tooltips-everywhere

import { Tooltip } from 'bootstrap';

const tooltipTriggerList = document.querySelectorAll('[data-bs-toggle="tooltip"]')
const tooltipList = [...tooltipTriggerList].map(tooltipTriggerEl => new bootstrap.Tooltip(tooltipTriggerEl))
