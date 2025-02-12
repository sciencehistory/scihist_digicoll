// TODO rename -- these are members, not works
let WorkBatch = (function () {

  document.querySelector(".work-batch-link")?.addEventListener("click", getMembers);

  function getFriendlierId() {
    var urlMatches = window.location.href.match(/\/works\/([^\/]*)/);
    return (urlMatches === null) ? null : urlMatches[1];
  }

  // Note: Batch zero is already present at page load.
  function getBatch() { 
    return parseInt(document.querySelector('.last-loaded-batch').innerHTML) || 1;
  }

  function incrementBatch() {
    return document.querySelector('.last-loaded-batch').innerHTML = (getBatch() + 1);
  }

  function allMembersLoaded() {
    return document.querySelectorAll('.show-member-list-items .show-member-list-item').length >= parseInt(document.querySelector('.member-count').innerHTML);
  }


  function getMembers(event) {
    var friendlierId = getFriendlierId();
    if (friendlierId !== null) {
      var url = "http://localhost:3000/works/" + friendlierId + "/work_batch" + "?batch=" + (getBatch() + 1);
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
        incrementBatch();
      }

      if (allMembersLoaded()) {
        document.querySelector(".work-batch-link").style.display = "none";
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

