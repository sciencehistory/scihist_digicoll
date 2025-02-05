let WorkBatch = (function () {
  let privateVariable = "I am private";


  function getFriendlierId() {
    var urlMatches = window.location.href.match(/\/works\/([^\/]*)/);
    if (urlMatches === null) {
      return;
    }
    return urlMatches[1];
  }

  function getMembers() {
    var friendlierId = getFriendlierId();
    if (friendlierId !== null) {
      var url = "http://localhost:3000/works/" + friendlierId + "/work_batch";
      getWorks(url);
    }
  }

  async function getWorks(url) {
    try {
      const response = await fetch(url);
      if (!response.ok) {
        throw new Error(`HTTP error! Status: ${response.status}`);
      }
      const html = await response.text();

      var tagToReplace = document.querySelector('div.show-member-list-items')
      if (tagToReplace !== null) {
        tagToReplace.innerHTML = html;
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

WorkBatch.getMembers();
