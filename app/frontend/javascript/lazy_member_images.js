function tagForImages() {
  return document.querySelector('.member-divs');
}

function getFriendlierId() {
  var urlMatches = window.location.pathname.match(/^\/works\/([^\/]*)/);
  return (urlMatches === null) ? null : urlMatches[1];
}

function constructUrl() {
  if (tagForImages() === null) {
    return;
  }
  var friendlierId = getFriendlierId();
  if (friendlierId === null) {
    return;
  }
  // there might be more than one of these tags on the page; we just want the contents of the last one.
  var startIndex = parseInt(Array.from(document.querySelectorAll('.next-start-index')).pop().innerHTML);

  var imagesPerPage =  parseInt(document.querySelector('.images-per-page').innerHTML);

  if (!Number.isInteger(startIndex + imagesPerPage)) {
    return;
  }
  return window.location.origin + "/works/" +
    friendlierId + "/lazy_member_images?" +
    "start_index=" + startIndex + '&images_per_page=' + imagesPerPage;
}

// Attempt to fetch the lazy member images, and insert them right before the end of a div:
async function fetchAndInsertLazyMemberImages(url) {
  console.log("Getting url " + url);

  try {
    // try getting the HTML
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`HTTP error! Status: ${response.status}`);
    }
    const html = await response.text();
    // pop it in the tag, right before the end
    tagForImages().insertAdjacentHTML('beforeend', html);
  }
  catch (error) {
    console.error('Error fetching or inserting HTML:', error);
  }

  // if there are no more images to fetch, hide the now-useless link
  if (document.querySelector(".no-more-images") !== null) {
    document.querySelector(".lazy-member-images-link").style.display = "none";
  }
}

function getMoreMemberImages(event) {
  event.preventDefault();
  var urlForMoreImages = constructUrl();
  if (urlForMoreImages) {
    fetchAndInsertLazyMemberImages(urlForMoreImages);
  }
}

document.querySelector(".lazy-member-images-link")?.addEventListener("click", getMoreMemberImages);