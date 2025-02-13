document.querySelector(".lazy-member-images-link")?.addEventListener("click", getMoreMemberImages);


function getMoreMemberImages(event) {
  var friendlierId = getFriendlierId();
  if (friendlierId !== null) {
    var url = "http://localhost:3000/works/" + friendlierId + "/lazy_member_images?" +
      "start_index=" + document.querySelector(".lazy-member-images-link").dataset.startIndex +
      '&images_per_page=' + document.querySelector(".lazy-member-images-link").dataset.imagesPerPage ;
    console.log("Getting url" + url);
    getWorks(url);

  }

  event.preventDefault();
}

// todo: get the entire url from the template
function getFriendlierId() {
  var urlMatches = window.location.href.match(/\/works\/([^\/]*)/);
  return (urlMatches === null) ? null : urlMatches[1];
}

// todo: get the entire url from the template
async function getWorks(url) {
    var tagToReplace = document.querySelector('.member-divs');
    if (tagToReplace === null) {
      return;
    }

  try {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`HTTP error! Status: ${response.status}`);
    }
    const html = await response.text();
    tagToReplace.insertAdjacentHTML('beforeend', html);


    // update the link so it works for the next batch:
    document.querySelector(".lazy-member-images-link").dataset.startIndex  = Array.from(document.querySelectorAll('.next-start-index')).pop().innerHTML

    if (allMembersLoaded()) {
      document.querySelector(".lazy-member-images-link").style.display = "none";
    }

  } catch (error) {
    console.error('Error fetching or inserting HTML:', error);
  }
}
