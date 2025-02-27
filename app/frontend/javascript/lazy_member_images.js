class LazyMemberImages {
  constructor() {
     document.querySelector(".lazy-member-images-link")?.addEventListener("click", this.#getMoreMemberImages.bind(this));
  }

  #getMoreMemberImages(event) {
    event.preventDefault();
    if (this.#tagForImages() === null) { return; }
    var urlForMoreImages = this.#constructUrl();
    if (urlForMoreImages) {
      this.#fetchAndInsertLazyMemberImages(urlForMoreImages);
    }
  }

  #constructUrl() {
    var friendlierId =  this.#getFriendlierId();
    var startIndex =    this.#getStartIndex();
    var imagesPerPage = this.#getImagesPerPage();
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
      // pop it in the tag, right before the end
      this.#tagForImages().insertAdjacentHTML('beforeend', html);
    }
    catch (error) {
      console.error('Error fetching or inserting HTML:', error);
    }

    // if there are no more images to fetch, hide the now-useless link
    if (document.querySelector(".no-more-images") !== null) {
      document.querySelector(".lazy-member-images-link").style.display = "none";
    }
  }

  // where to insert the images
  #tagForImages() {
    return document.querySelector('.member-divs');
  }

  #getFriendlierId() {
    var urlMatches = window.location.pathname.match(/^\/works\/([^\/]*)/);
    return (urlMatches === null) ? null : urlMatches[1];
  }

  // there might be more than one of these tags on the page.
  // We just want the contents of the last one.
  #getStartIndex() {
    return parseInt(Array.from(document.querySelectorAll('.next-start-index')).pop().innerHTML);
  }

  #getImagesPerPage() {
    return parseInt(document.querySelector('.images-per-page').innerHTML);
  }
}

const lazyMemberImagesObject = new LazyMemberImages();

