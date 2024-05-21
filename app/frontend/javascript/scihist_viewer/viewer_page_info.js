// Holds in memory page info for the viewer returned by the server.
//
// Keeps it indexed so we can look up a member-id and get a page index back too --
// that correspondence is needed for our viewer search stuff, especially ability to
// find "first hit after page N"

export default class ViewerSearchResults {
  constructor(jsonInfo) {
    self._jsonInfo = jsonInfo;

    // OK, make an object for reverse lookup
    const idToIndex = {};
    self._jsonInfo.forEach(function (value, index) {
      idToIndex[value.memberId] = index;
    });
    self._idToIndex = idToIndex;
  }

  // @param index [Integer] 0-based index into ordered list, return
  // the object with page info for that index. Object is as returned by server.
  //
  // it's a kind of complicated object not entirely documented sorry, but looks like eg:
  //
  // {
  //   "index": 5,
  //   "memberShouldShowInfo": false,
  //   "title": "b1027226_005.tif",
  //   "memberId": "c534fp43r",
  //   "memberShowUrl": null,
  //   "tileSource": "https://scih-data-dev.s3.amazonaws.com/jrochkind.jrochkind-shi.local/dzi/25962322-7de9-4bc3-84ef-953fdb2fb5ef/md5_99b699d6a8819d1291b15699b0369eae.dzi",
  //   "fallbackTileSource": {
  //     "type": "image",
  //     "url": "/downloads/deriv/c534fp43r/download_medium?disposition=inline"
  //   },
  //   "thumbAspectRatio": "0.7044788614483047",
  //   "downloads": [
  //     {
  //       "url": "/downloads/deriv/c534fp43r/download_medium",
  //       "label": "Small JPG",
  //       "subhead": "1200 x 1703px — 208 KB",
  //       "analyticsAction": "download_jpg_medium"
  //     },
  //     {
  //       "url": "/downloads/deriv/c534fp43r/download_large",
  //       "label": "Large JPG",
  //       "subhead": "2880 x 4088px — 1.3 MB",
  //       "analyticsAction": "download_jpg_large"
  //     },
  //     {
  //       "url": "/downloads/deriv/c534fp43r/download_full",
  //       "label": "Full-sized JPG",
  //       "subhead": "3366 x 4778px — 1.8 MB",
  //       "analyticsAction": "download_jpg_full"
  //     },
  //     {
  //       "url": "/downloads/orig/image/c534fp43r",
  //       "label": "Original file",
  //       "subhead": "TIFF — 3366 x 4778px — 46.1 MB",
  //       "analyticsAction": "download_original"
  //     }
  //   ],
  //   "thumbSrc": "https://scih-data-dev.s3.amazonaws.com/jrochkind.jrochkind-shi.local/derivatives/25962322-7de9-4bc3-84ef-953fdb2fb5ef/thumb_mini/c412ad58c0fb50984109280b2db1917b.jpg",
  //   "thumbSrcset": "https://scih-data-dev.s3.amazonaws.com/jrochkind.jrochkind-shi.local/derivatives/25962322-7de9-4bc3-84ef-953fdb2fb5ef/thumb_mini/c412ad58c0fb50984109280b2db1917b.jpg 1x, https://scih-data-dev.s3.amazonaws.com/jrochkind.jrochkind-shi.local/derivatives/25962322-7de9-4bc3-84ef-953fdb2fb5ef/thumb_mini_2X/be28b7ecb00864f3eb4dd796bc32d7c6.jpg 2x"
  // }
  //
  getPageInfoByIndex(index) {
    return self._jsonInfo[index];
  }

  getIndexByMemberId(memberId) {
    return self._idToIndex[memberId];
  }
}
