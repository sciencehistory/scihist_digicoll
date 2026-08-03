import domready from 'domready';
import { Collapse } from 'bootstrap';

domready(function() {
  const toggle = document.getElementById("showVideoTranscriptToggle");
  const transcriptCollapsible = document.getElementById('show-video-transcript-collapse');

  if (transcriptCollapsible && toggle) {
    transcriptCollapsible.addEventListener('shown.bs.collapse', event => {
      // jump to transcript if needed
      const bounding = transcriptCollapsible.getBoundingClientRect();
      if (bounding && !(bounding.bottom >= 0 && bounding.top <= document.documentElement.clientHeight)) {
        transcriptCollapsible.scrollIntoView();
      }
    });

    transcriptCollapsible.addEventListener('show.bs.collapse', event => {
      toggle.style.display = "none"; // hide toggle botton
    });

    transcriptCollapsible.addEventListener('hide.bs.collapse', event => {
      toggle.style.display = ""; // show toggle botton
    });
  }
});
