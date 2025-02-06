let WorkBatch = (function () {
  let privateVariable = "I am private";

  document.querySelector(".work-batch-link")?.addEventListener("click", getMembers);

  function getFriendlierId() {
    var urlMatches = window.location.href.match(/\/works\/([^\/]*)/);
    return (urlMatches === null) ? null : urlMatches[1];
  }

  function getPage() { 
    return parseInt(document.querySelector('.last-loaded-page').innerHTML) || 0;
  }

  function incrementPage() {
    document.querySelector('.last-loaded-page').innerHTML = (getPage() + 1);
  }


  function getMembers(event) {
    var friendlierId = getFriendlierId();
    if (friendlierId !== null) {
      var url = "http://localhost:3000/works/" + friendlierId + "/work_batch" + "?page=" + (getPage() + 1);
      getWorks(url);
    }
    event.preventDefault();
  }

  async function getWorks(url) {
    try {
      const response = await fetch(url);
      if (!response.ok) {
        throw new Error(`HTTP error! Status: ${response.status}`);
      }
      const html = await response.text();

      var tagToReplace = document.querySelector('div.show-member-list-items');
      if (tagToReplace !== null) {
        tagToReplace.insertAdjacentHTML('beforeend', html);
        incrementPage();
      }
    } catch (error) {
      console.error('Error fetching or inserting HTML:', error);
    }
  }

  // return for the class:
  return {
    getMembers: getMembers,
  };

})();

