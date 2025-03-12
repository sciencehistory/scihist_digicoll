// GET a batch of thumbnails from the lazy images method in the public works controller. A typical path to GET would be:
//      /works/WORK_FRIENDLIER_ID/lazy_member_images?start_index=100&images_per_page=100
// and then insert them directly into the DOM.
//
// This is intended to speed up the perceived loading of books with over 500 pages.
// See https://github.com/sciencehistory/scihist_digicoll/issues/905 for context.
//
// See also :
//   app/components/work_image_show_component.rb
//      (provides this script with friendlierID, startIndex, and imagesPerPage)
//   app/controllers/works_controller.rb#lazy_member_images
//      (provides this script with the images)
//
// Contains no JQuery code.

class LazyMemberImages {

  constructor() {
    document.querySelector(".work-show")?.addEventListener("click", (event) => {
      const link = event.target.closest('[data-trigger="lazy-member-images"]');

      if (link) {
        event.preventDefault();
        this.#getMoreMemberImages(link);
      }
    });
  }

  // Retrieve the images and insert them
  #getMoreMemberImages(linkEl) {

    // The zero-based index of the next image to fetch.
    const startIndex = parseInt(linkEl.getAttribute("data-start-index"));

    // How many images to request.
    const imagesPerPage = parseInt(linkEl.getAttribute("data-images-per-page"));

    var urlForMoreImages = this.#constructUrl(startIndex, imagesPerPage);
    if (urlForMoreImages) {
      this.#fetchAndInsertLazyMemberImages(urlForMoreImages);
    }
  }


  // Calculate the URL where the images can be GETted from
  #constructUrl(startIndex, imagesPerPage) {
    var friendlierId =  this.#getFriendlierId();

    if (friendlierId === null || !Number.isInteger( startIndex + imagesPerPage)) {
      console.error('Could not calculate friendlier ID, start index, or images per page:');
      return;
    }

    return window.location.origin + "/works/" +
      friendlierId + "/lazy_member_images?" +
      "start_index=" + startIndex + '&images_per_page=' + imagesPerPage;
  }

  // Attempt to fetch the lazy member images, and insert them right before the end of a div:
  async #fetchAndInsertLazyMemberImages(url) {
    try {
      // try getting the HTML
      const response = await fetch(url);
      if (!response.ok) {
        throw new Error(`HTTP error! Status: ${response.status}`);
      }
      const html = await response.text();

      // put it into page REPLACING existing link -- this HTML will have another
      // link if needed.
      document.querySelector('*[data-trigger="lazy-member-images"]').outerHTML = html;
    }
    catch (error) {
      console.error('Error fetching or inserting HTML:', error);
    }
  }

  // this work's friendlier ID
  #getFriendlierId() {
    var urlMatches = window.location.pathname.match(/^\/works\/([^\/]*)/);
    return (urlMatches === null) ? null : urlMatches[1];
  }
}

const lazyMemberImagesObject = new LazyMemberImages();

