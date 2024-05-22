export default class ViewerSearchResults {

  // @param jsonResults [json] json as returned by server for search results
  //
  // @param pageInfo [ViewerPageInfo] object we use temporarily to look up page indexes to assign,
  //   we don't keep a reference.
  constructor(jsonResults, pageInfo) {
    // Results stored, enhanced with index, they should look like an array of
    // {
    //    member_id: memberId,
    //    text: snippetText,
    //    resultIndex: {0..length-1},
    //    pageIndex: {0..totalPages-1},
    //    osd_rect: {
    //      left: l,  # in OSD whole-image-widht units
    //      top: t,
    //      height: h,
    //      width: w
    //    }
    // }
    this._jsonResults = jsonResults;

    // * Add index number (0..n) to each result for convenience
    //
    // * Add the PAGE index into total page results, need for looking up results
    //
    // * Index each OSD highlight dimensions in a hash by member Id
    //
    // _highlightsByPageId will be a lookup keyed by Asset page friendlier
    // ID, where values are an array of objects, where each has OpenSeadragon values
    // for x y width height (all proportional between 0 and 1), degrees, and anything else we need.
    // https://openseadragon.github.io/docs/OpenSeadragon.Rect.html
    //
    // {
    //   "bksm7ln" : [
    //     {"left":0.30731,"top":1.37769,"width":0.09654,"height":0.01808},
    //   ]
    // }
    //

    let i = 0;
    this._resultsByPageId = {};
    for (const result of this._jsonResults) {
      // Add index number (0..n) to each result for convenience
      result['resultIndex'] = i;
      i++;

      const memberID = result['member_id'];

      // Add the PAGE index into total page results, need for looking up results
      result['pageIndex'] = pageInfo.getIndexByMemberId(memberID);

      // Index each OSD highlight dimensions in a hash by member Id
      this._resultsByPageId[memberID] = (this._resultsByPageId[memberID] || []);
      this._resultsByPageId[memberID].push(result);
    }
  }

  resultsByPageId(pageId) {
    return this._resultsByPageId[pageId] || []
  }

  // straight json results from server, but with resultIndex too
  jsonResults() {
    return this._jsonResults;
  }

  resultByIndex(index) {
    return this._jsonResults[index];
  }

  resultsCount() {
    return this._jsonResults.length;
  }

  resultsCountMessage() {
    if (this.resultsCount() == 1) {
      return  "1 result"
    } else {
      return this.resultsCount() + " results";
    }
  }

  // @param {Integer} pageIndex 1-based current page index
  //
  // Find first result that is on the page with pageIndex given, or first page
  // after that.
  nextResultFromPageIndex(pageIndex) {
    // Have to subtract one cause the argument was a 1-based base pagge index
    return this._jsonResults.find( (element) => element.pageIndex >= pageIndex - 1);
  }

  // @param {Integer} pageIndex 1-based current page index
  //
  // Find first result that is on the page with pageIndex given, or closest PREVIOUS
  // page before that.
  previousResultFromPageIndex(pageIndex) {
    // Have to subtract one cause the argument was a 1-based base pagge index
    return this._jsonResults.findLast( (element) => element.pageIndex <= pageIndex - 1);
  }
}
