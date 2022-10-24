// A "jump to text" button will scroll to portion of transcript matching current timecode
// in player. OR if you are in ToC tab, open/scroll to segment of ToC matching current timecode.

import {gotoTocSegmentAtTimecode, gotoTranscriptTimecode, getActiveTab} from "./helpers/ohms_player_helpers.js";
import domready from 'domready';

domready(function() {
  document.body.addEventListener("click", function (event) {
    if (event.target.matches("*[data-trigger='ohms-jump-to-text']")) {
      var player = document.querySelector("audio[data-role=ohms-audio-elem]");
      var timeCodeSeconds = player.currentTime;
      var activeTab = getActiveTab();

      // if we are on the Toc tab OR we don't have a transcript tab to go to.
      if (activeTab.id == "ohTocTab" || !document.querySelector("#ohTranscript")) {
        gotoTocSegmentAtTimecode(timeCodeSeconds)
      } else if (activeTab) {
        // if we have anything else, jump to transcript point, activating
        // transcript tab first if needed.
        if (activeTab.id != "ohTranscriptTab") {
          $('*[data-toggle="tab"][href="#ohTranscript"]').tab("show");
        }
        gotoTranscriptTimecode(timeCodeSeconds)
      }
    }
  });
});


