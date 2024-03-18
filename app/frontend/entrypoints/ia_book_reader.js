// Loads JQuery into window.jQuery and window.$, where BookReader expects it globally
import "../ia_book_reader/jquery_setup.js";

import  "@internetarchive/bookreader/BookReader/BookReader.css";
import  "@internetarchive/bookreader/BookReader/BookReader.js";

// BookReader wrapper web component
import "@internetarchive/bookreader/BookReader/ia-bookreader-bundle.js"

async function loadBookReader(pageDataUrl) {
  // Get the url to load page data, load the page data, then load the book reader with it!
  const response = await fetch(pageDataUrl);
  const readerData = await response.json();

  // As a proof of concept we're just hard-coding in some pages from staging...
  var options = {
    el: "#SciHistBookReader",

    data: readerData,

    bookTitle: 'PLACEHOLDER',

    // thumbnail is optional, but it is used in the info dialog
    //thumbnail: '//staging-digital.sciencehistory.org/downloads/deriv/cg1vakf/thumb_standard?disposition=inline',

    // Metadata is optional, but it is used in the info dialog
    // metadata: [
    //   {label: 'Title', value: 'Letter from Thomas H. Garrett to Margaret M. Booth'},
    // ],

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
      const urlOptions = this.book.getPageProp(index, 'img_by_width');

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
}

document.addEventListener('DOMContentLoaded', function () {
  const pageDataUrl = $("#SciHistBookReader").data("page-data-url");

  if (!pageDataUrl) {
    console.error("Could not find data url to load BookReader")
    return
  }

  loadBookReader(pageDataUrl);
});
