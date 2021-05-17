// This turns on all generic Bootstrap tooltips.
// Note also app/javascript/src/js/ohms_footnotes.js, used exclusively
// to show hover-over citations on footnote references in
// OHMS  transcripts.
$( document ).ready(function() {
    jQuery('[data-toggle="tooltip"]').tooltip();
});