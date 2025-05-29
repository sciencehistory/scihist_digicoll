import domready from 'domready';
import { Collapse } from 'bootstrap';

domready(function() {
  const toggle = document.getElementById("showVideoTranscriptToggle");
  const transcriptCollapsible = document.getElementById('show-video-transcript-collapse');

  if (transcriptCollapsible && toggle) {
    transcriptCollapsible.addEventListener('shown.bs.collapse', event => {
      toggle.textContent = toggle.dataset.hideLabel;
    });
    transcriptCollapsible.addEventListener('hidden.bs.collapse', event => {
      toggle.textContent = toggle.dataset.showLabel;
    });
  }
});
