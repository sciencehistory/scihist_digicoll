import domready from 'domready';
import { Collapse } from 'bootstrap';

domready(function() {
  const toggle = document.getElementById("showVideoTranscriptToggle");
  const transcriptCollapsible = document.getElementById('show-video-transcript-collapse');
  const transcriptContent = transcriptCollapsible && transcriptCollapsible.querySelector('[data-transcript-content-target]');

  if (transcriptCollapsible && toggle) {
    transcriptCollapsible.addEventListener('shown.bs.collapse', event => {
      // jump to transcript if needed
      const bounding = transcriptCollapsible.getBoundingClientRect();
      if (bounding && !(bounding.bottom >= 0 && bounding.top <= document.documentElement.clientHeight)) {
        transcriptCollapsible.scrollIntoView();
      }

      // move focus into the transcript, since the toggle button that had focus is now hidden
      if (transcriptContent) {
        transcriptContent.focus();
      }
    });

    transcriptCollapsible.addEventListener('show.bs.collapse', event => {
      toggle.style.display = "none"; // hide toggle botton
    });

    transcriptCollapsible.addEventListener('hide.bs.collapse', event => {
      toggle.style.display = ""; // show toggle botton
    });

    transcriptCollapsible.addEventListener('hidden.bs.collapse', event => {
      // return focus to toggle, since the close button that had focus is now hidden
      toggle.focus();
    });
  }
});
