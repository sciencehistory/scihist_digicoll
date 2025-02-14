document.querySelector(".lazy-member-images-link")?.addEventListener("click", getMoreMemberImages);


function getMoreMemberImages(event) {
  var friendlierId = getFriendlierId();
  var startIndex = document.querySelector(".lazy-member-images-link").dataset.startIndex;
  var imagesPerPage = document.querySelector(".lazy-member-images-link").dataset.imagesPerPage;
  if (friendlierId !== null) {
    var url = window.location.origin + "/works/" + friendlierId + "/lazy_member_images?" +
      "start_index=" + startIndex + '&images_per_page=' + imagesPerPage;
    console.log("Getting url" + url);
    getWorks(url);
  }
  event.preventDefault();
}

function getFriendlierId() {
  var urlMatches = window.location.href.match(/\/works\/([^\/]*)/);
  return (urlMatches === null) ? null : urlMatches[1];
}

// todo: get the entire url from the template
async function getWorks(url) {
    var tagForImages = document.querySelector('.member-divs');
    if (tagForImages === null) {
      return;
    }

  try {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`HTTP error! Status: ${response.status}`);
    }
    const html = await response.text();
    tagForImages.insertAdjacentHTML('beforeend', html);

    // if there are no more images to fetch
    if (document.querySelector(".no-more-images") !== null) {
      // hide the now-useless link
      document.querySelector(".lazy-member-images-link").style.display = "none";
    }
    else {
      // update the link so it knows about the next batch:
      document.querySelector(".lazy-member-images-link").dataset.startIndex  = parseInt(Array.from(document.querySelectorAll('.next-start-index')).pop().innerHTML);
    }

  } catch (error) {
    console.error('Error fetching or inserting HTML:', error);
  }
}
