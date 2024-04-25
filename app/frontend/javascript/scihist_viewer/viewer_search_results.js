export default class ViewerSearchResults {
  constructor(jsonResults) {
    // Results stored, enhanced with index, they should look like an array of
    // {
    //    id: memberId,
    //    text: snippetText,
    //    resultIndex: {0..length-1},
    //    osd_rect: {
    //      left: l,  # in OSD whole-image-widht units
    //      top: t,
    //      height: h,
    //      width: w
    //    }
    // }
    this._jsonResults = jsonResults;

    // Add index number (0..n) to each result for convennience, and also
    // Index each OSD highlight dimensions in a hash by member Id
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
    this._highlightsByPageId = {};
    for (const result of this._jsonResults) {
      result['resultIndex'] = i;
      i++;

      const id = result['id'];
      this._highlightsByPageId[id] = (this._highlightsByPageId[id] || []);
      this._highlightsByPageId[id].push(result.osd_rect);
    }
  }

  highlightsByPageId(pageId) {
    return this._highlightsByPageId[pageId] || []
  }

  // straight json results from server, but with resultIndex too
  jsonResults() {
    return this._jsonResults;
  }

  resultByIndex(index) {
    return this._jsonResults[index];
  }
}
