// Holds in memory page info for the viewer returned by the server.
//
// Keeps it indexed so we can look up a member-id and get a page index back too --
// that correspondence is needed for our viewer search stuff, especially ability to
// find "first hit after page N"

export default class ViewerSearchResults {
  constructor(jsonInfo) {
    self._jsonInfo = jsonInfo;
  }

  // @param index [Integer] 0-based index into ordered list, return
  // the object with page info for that index. Object is as returned by server,
  // so looks like eg:
  //
  //
  pageInfoByIndex(index) {
    return self._jsonInfo[index];
  }

}
