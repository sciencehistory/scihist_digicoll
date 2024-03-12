// Loads JQuery into window.jQuery and window.$, where BookReader expects it globally
import "../ia_book_reader/jquery_setup.js";

import  "@internetarchive/bookreader/BookReader/BookReader.css";
import  "@internetarchive/bookreader/BookReader/BookReader.js";

// BookReader wrapper web component
import "@internetarchive/bookreader/BookReader/ia-bookreader-bundle.js"

document.addEventListener('DOMContentLoaded', function () {

  // As a proof of concept we're just hard-coding in some pages from staging...
  var options = {
    el: "#SciHistBookReader",

    data: [
      [
        { width: 2922, height: 4639, ppi: 580,
          //uri: '//staging-digital.sciencehistory.org/downloads/deriv/cg1vakf/download_full?disposition=inline',
          // widths to urls
          scihist_urls: {
             54: "//staging-digital.sciencehistory.org/downloads/deriv/cg1vakf/thumb_mini?disposition=inline",
             108: "//staging-digital.sciencehistory.org/downloads/deriv/cg1vakf/thumb_mini_2X?disposition=inline",
             208: "//staging-digital.sciencehistory.org/downloads/deriv/cg1vakf/thumb_standard?disposition=inline",
             416: "//staging-digital.sciencehistory.org/downloads/deriv/cg1vakf/thumb_standard_2X?disposition=inline",
             525: "//staging-digital.sciencehistory.org/downloads/deriv/cg1vakf/thumb_large?disposition=inline",
             1050: "//staging-digital.sciencehistory.org/downloads/deriv/cg1vakf/thumb_large_2X?disposition=inline",
             1200: "//staging-digital.sciencehistory.org/downloads/deriv/cg1vakf/download_medium?disposition=inline",
             2880: "//staging-digital.sciencehistory.org/downloads/deriv/cg1vakf/download_large?disposition=inline",
             2922: "//staging-digital.sciencehistory.org/downloads/deriv/cg1vakf/download_full?disposition=inline"
          }
        },
        { width: 2905, height: 4639, ppi: 580,
          //uri: '//staging-digital.sciencehistory.org/downloads/deriv/77j6z3w/download_full?disposition=inline',
          scihist_urls: {
           54: "//staging-digital.sciencehistory.org/downloads/deriv/cg1vakf/thumb_mini?disposition=inline",
           108: "//staging-digital.sciencehistory.org/downloads/deriv/cg1vakf/thumb_mini_2X?disposition=inline",
           208: "//staging-digital.sciencehistory.org/downloads/deriv/cg1vakf/thumb_standard?disposition=inline",
           416: "//staging-digital.sciencehistory.org/downloads/deriv/cg1vakf/thumb_standard_2X?disposition=inline",
           525: "//staging-digital.sciencehistory.org/downloads/deriv/cg1vakf/thumb_large?disposition=inline",
           1050: "//staging-digital.sciencehistory.org/downloads/deriv/cg1vakf/thumb_large_2X?disposition=inline",
           1200: "//staging-digital.sciencehistory.org/downloads/deriv/cg1vakf/download_medium?disposition=inline",
           2880: "//staging-digital.sciencehistory.org/downloads/deriv/cg1vakf/download_large?disposition=inline",
           2905: "//staging-digital.sciencehistory.org/downloads/deriv/cg1vakf/download_full?disposition=inline"
          }
        },
      ],
    ],

    bookTitle: 'Letter from Thomas H. Garrett to Margaret M. Booth',

    // thumbnail is optional, but it is used in the info dialog
    thumbnail: '//staging-digital.sciencehistory.org/downloads/deriv/cg1vakf/thumb_standard?disposition=inline',

    // Metadata is optional, but it is used in the info dialog
    metadata: [
      {label: 'Title', value: 'Letter from Thomas H. Garrett to Margaret M. Booth'},
    ],

    ui: 'full', // embed, full (responsive)

    // index is 0-based index into data, which is annoying
    // reduce is a reduction factor -- 2 means 1/2 (50%), 4 is 25% etc. Unclear if it ever sends higher than 4
    // rotate is an (integer?) representing rotation, but current bookreader seems not to ever send this anyway
    //
    // This custom routine tries to find the derivative we have available that is CLOSEST to the reduction
    // the reader requests, since we don't currently always have even reductions. We want the smallest
    // available derivative at least as big as 90% of what reader requests.
    //
    // TODO improve logic, it shouldn't take 90% if 100% or 101% is available!
    getPageURI: function(index, reduce, rotate) {
      if (reduce == 0) {
        // don't know what the BookReader means by this or why it does it
        return undefined;
      }

      const fullWidth = this.book.getPageProp(index, 'width');
      const targetWidth = fullWidth / reduce;
      const urlOptions = this.book.getPageProp(index, 'scihist_urls');

      try {
        // Find the smallest image that is at least 90% of what we want
        const [_width, url] = Object.entries(urlOptions).find( ([width, _url]) => width >= (targetWidth * .9) );

        console.log("index:" + index+ " reduction:" + reduce + " targetWidth:" + targetWidth + " actualWidth:" + _width + " url: " + url)
        return url;
      }
      catch(err) {
        debugger;
        1+1;
      }
    },

    reduceSet: 'integer'
  };


  var ourReaderInstance = new BookReader(options);

  // Let's go!
  ourReaderInstance.init();
});
