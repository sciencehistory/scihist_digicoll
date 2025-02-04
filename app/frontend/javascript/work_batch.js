let WorkBatch = (function () {
  let privateVariable = "I am private";


  async function getWorks(url) {
    try {
      const response = await fetch(url);
      if (!response.ok) {
        throw new Error(`HTTP error! Status: ${response.status}`);
      }

      const html = await response.text();

      document.querySelector('div.show-member-list-items').innerHTML = html;
    } catch (error) {
      console.error('Error fetching or inserting HTML:', error);
    }
  }


  function getMembers() {
    getWorks("http://localhost:3000/works/qbtvy9p/work_batch");
  }

  return {
    getMembers: getMembers,
  };

})();

//WorkBatch.getMembers();
