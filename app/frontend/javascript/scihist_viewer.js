// A JS 'class' for dealing with the image viewer.
//
//   * Depends on JQuery being available, although not imported webpacker style
//   * Depends on Bootstrap modal JS being available, although not imported webpacker style
//
// Image viewer is triggered with an <a> tag with these data attributes:
//
//   * data-trigger='scihist_image_viewer' : triggers viewer
//   * data-member-id=[friendly_id]: optional, ID of member (from data-images-info-path data) to select in viewer.
//
// Assumes a bootstrap modal for viewer is available at DOM id #scihist-image-viewer-modal, it has to have
// a data-work-id and data-images-info-path (URL to JSON images info) for the work. Yes, that means
// right now we assume on a given page, a viewer will only be displayed for ONE single work. data-images-info-path
// is a URL that will return JSON, see ViewerMemberInfoSerializer for what it looks like. It also has
// a 'template' for download links menu. This is one of the hackiest/least generalizable parts of the implementation.
//
// Note the viewer updates the URL to add a "viewer/[memberId]" reference, so you can bookmark or link to viewer open
// to certain member. Routes need to route that to ordinary show page, let JS pick up the end of the path.
//
// ## Extract to a re-usable component for other apps?
//
// It would be nice and we're trying to write it with that end in mind, but there are still
// plenty of places that lack customizability or make odd undocumented assumptions about the
// app, it would take signifcant more work. :(

import OpenSeadragon from 'openseadragon';
import ViewerSearchResults from '../javascript/scihist_viewer/viewer_search_results.js';
import ViewerPageInfo from '../javascript/scihist_viewer/viewer_page_info.js';

function ScihistImageViewer() {
  var modal = document.querySelector("#scihist-image-viewer-modal");
  if (!modal) {
    console.log("ERROR: Could not find modal element for viewer");
  }
  this.initModal(modal);
}

ScihistImageViewer.prototype.viewerPathComponentRe = /\/viewer\/(\w+)$/;

// In pixels, has to match CSS, and should match actual width of
// thumbnails generated and delivered in JSON info.
ScihistImageViewer.prototype.thumbWidth = "54";

// A ViewerPageInfo obj once loaded
ScihistImageViewer.prototype.pageInfo = undefined;

// A ViewerSearchResults obj or undefined
ScihistImageViewer.prototype.searchResults = undefined;

// and we store the current query if any
ScihistImageViewer.prototype.currentSearchQuery = undefined;

// last iterated result for next/prev through results
ScihistImageViewer.prototype.currentSearchResult = undefined;

// For persisting zoom level as you change pages
ScihistImageViewer.prototype.restoreZoomValue = undefined;

ScihistImageViewer.prototype.findThumbElement = function(memberId) {
  return document.querySelector(".viewer-thumb[data-member-id='" + memberId + "']");
};

ScihistImageViewer.prototype.show = function(id) {
  if (document.activeElement) {
    this.previousFocus = document.activeElement;
  }

  if (typeof this.viewer == "undefined") {
    this.initOpenSeadragon();
  }

  if (! OpenSeadragon.supportsFullScreen) {
    this.hideUiElement(document.querySelector("#viewer-fullscreen"));
  }
  if (! this.viewer.drawer.canRotate()) {
    //OSD says no rotate
    this.hideUiElement(document.querySelector("#viewer-rotate-right"));
  }

  var _self = this;
  // Make sure we don't try to do this before thumbs are loaded
  this.thumbsLoadedGuard.then(function() {
    if (_self.totalCount == 1) {
      // hide multi-item-relevant controls
      _self.hideUiElement(document.querySelector("#viewer-pagination"));
      _self.hideUiElement(document.querySelector("#viewer-right"));
      _self.hideUiElement(document.querySelector("#viewer-left"));
      _self.hideUiElement(document.querySelector("#viewer-thumbs"));
    } else {
      document.getElementsByClassName('viewer-pagination-denominator').item(0).textContent = _self.totalCount;
    }

    var selectedThumb;
    // find the thumb
    if (id) {
      selectedThumb = _self.findThumbElement(id);
    }
    if (! selectedThumb) {
      // just use the first one
      selectedThumb = document.querySelector(".viewer-thumb");
    }
    _self.selectThumb(selectedThumb);

    // restore to bookmarkable URL if we have a current search
    if (_self.currentSearchQuery) {
      _self.storeQueryInUrl(_self.currentSearchQuery);
    }

    // show the viewer
    $(_self.modal).modal("show");

    // make sure openseadragon has initial zoom level set to full page,
    // ONCE the modal is fully shown and we're in state where we have
    // the correct size, we hook into after the OSD resize event.
    //
    // https://github.com/openseadragon/openseadragon/discussions/2279
    _self.viewer.addOnceHandler('resize',function(event){
      window.setTimeout(()=>event.eventSource.viewport.goHome(true));
    });

    // make sure selected thumb in thumb list is in view
    _self.scrollSelectedIntoView();

    // If we have a query in the URL, and don't already have a search loaded, load it
    if (! _self.currentSearchQuery) {
      const queryFromUrl = _self.getQueryInUrl();
      if (queryFromUrl) {
        _self.modal.find("#q").val(queryFromUrl); // set in search box in viewer
        _self.getSearchResults(queryFromUrl);
        _self.showSearchDrawer();
      }
    }

    // Catch keyboard controls
    $("body").on("keydown.chf_image_viewer", function(event) {
      _self.onKeyDown(event);
    });
  });
};

// Scroll given element into view only if it's not already in full view. Unlike built-into
// browser function which always scrolls so it's at the top, even if it already was in view.
//
ScihistImageViewer.prototype.scrollElementIntoView = function(elem, container) {
  // only if the selected thing is not currently in scroll view, scroll
  // it to be so.
  // https://stackoverflow.com/a/16309126/307106

  if (container == undefined) {
    container = elem.parentNode;
  }
  const jqContainer = $(container);

  const contHeight = jqContainer.height();
  const contTop = jqContainer.scrollTop();
  const contBottom = contTop + contHeight ;

  const contWidth = jqContainer.width();
  const contLeft = jqContainer.scrollLeft();
  const contRight = contLeft + contWidth;


  const elemTop = $(elem).offset().top - jqContainer.offset().top;
  const elemBottom = elemTop + $(elem).height();
  const elemLeft = $(elem).offset().left - jqContainer.offset().left;
  const elemRight = elemLeft + $(elem).width();

  // Not sure why the +1 correction was needed
  const onScreenVertical = (elemTop >= 0 && elemBottom <= contHeight+1);
  const onScreenHorzontal = (elemLeft >= 0 && elemRight <= contWidth);

  if (!onScreenVertical || !onScreenHorzontal) {

    // We want to use smooth scholl with elem.ScrollIntoView, but there's a bug in Chrome
    // where it can't do two  smooth scrolls at once, and we sometimes have both page thumb list and
    // search result list.
    //
    // https://stackoverflow.com/questions/49318497/google-chrome-simultaneously-smooth-scrollintoview-with-more-elements-doesn
    //
    // So we have to implement scrollIntoView in terms of container.scrollTo instead, as bug does not
    // exhibit there.

    if (!onScreenVertical) {
      const calculatedOffset = elem.offsetTop - container.offsetTop - container.getBoundingClientRect().height/2 + elem.getBoundingClientRect().height/2;
      container.scrollTo({top: calculatedOffset, behavior: 'smooth'});
    } else {
      // horzontal scroll
      const calculatedOffset = elem.offsetLeft - container.offsetLeft - container.getBoundingClientRect().width/2 + elem.getBoundingClientRect().width/2;
      container.scrollTo({left: calculatedOffset, behavior: 'smooth'});
    }

    // This would be the simpler way but for bug in Chrome
    //
    // elem.scrollIntoView({
    //     behavior: 'smooth',
    //     block: 'center',
    //     inline: 'center'
    // });
  }
}

ScihistImageViewer.prototype.scrollSelectedIntoView = function() {
  this.scrollElementIntoView(this.selectedThumb)
}

ScihistImageViewer.prototype.hide = function() {
  if (OpenSeadragon.isFullScreen()) {
    OpenSeadragon.exitFullScreen();
  }

  $("body").off("keydown.chf_image_viewer");

  this.viewer.close();
  $(this.modal).modal("hide");
  this.removeLocationUrl();
  this.removeQueryInUrl();
  this.restoreFocus();
};


ScihistImageViewer.prototype.restoreFocus =  function() {
  if(this.previousFocus) {
    this.previousFocus.focus();
    this.previousFocus = undefined;
  }
};

ScihistImageViewer.prototype.addLoading =  function() {
  this.loadingSpinnerDisplayed = true;
  var loading = $(".viewer-image-loading");
  if (loading.length > 0) {
    loading.show();
  } else {
    $(".viewer-image").append("<div class='viewer-image-loading'></div>");
  }
}

ScihistImageViewer.prototype.removeLoading =  function() {
  if (this.loadingSpinnerDisplayed) {
    $(".viewer-image-loading").hide();
    this.loadingSpinnerDisplayed = false;
  }
};

// @param thumbElement a DOM element for a thumbnail in the thumbnail list, to load that image
//
// @param {Boolean} resetCurrentSearchResult default true, will unselect any currently selected
//    search result, since we'e done a page change making it no longer active. But when being
//    done as part of search navigation itself, caller can pass in false.
//
// @example
//
//     this.selectThumb(domElement)
//     this.selectThumb(domElement, { resetCurrentSearchResult: false })
//
ScihistImageViewer.prototype.selectThumb = function(thumbElement , { resetCurrentSearchResult = true } = {}) {
  this.selectedThumb = thumbElement;

  var index = parseInt(thumbElement.getAttribute("data-index"));
  var humanIndex = index + 1;
  this.selectedThumbData = this.pageInfo.getPageInfoByIndex(index);

  // toggle classes
  $('.viewer-thumbs .viewer-thumb-selected').removeClass('viewer-thumb-selected')
  thumbElement.classList.add('viewer-thumb-selected');

  // Normally we reset any current search result on page change, unless this was being
  // done to go to a search result!
  if (this.searchResults && this.currentSearchResult && resetCurrentSearchResult) {
    $(".result.current-viewer-result").removeClass("current-viewer-result");
    document.getElementById("searchNavLabel").textContent = this.searchResults.resultsCountMessage();
    this.currentSearchResult = undefined;
  }


  var id = this.selectedThumbData.memberId;
  var shouldShowInfo = this.selectedThumbData.memberShouldShowInfo;
  var title = this.selectedThumbData.title;
  var linkUrl = this.selectedThumbData.memberShowUrl;
  var tileSource = this.selectedThumbData.tileSource;

  // hide any currently visible alerts, they only apply to
  // previously current image.
  $(this.modal).find(".viewer-alert").remove();

  // store zoom to restore same zoom, if present
  this.restoreZoomValue = this.viewer?.viewport?.getZoom();

  this.viewer.close();

  this.addLoading();
  this.viewer.open(tileSource);

  document.querySelector('*[data-hook="viewer-navbar-title-label"]').textContent = title;
  document.querySelector('*[data-hook="viewer-navbar-info-link"]').href = linkUrl;
  document.getElementsByClassName('viewer-pagination-numerator').item(0).textContent = humanIndex;

  $(this.modal).find(".downloads *[data-slot='selected-downloads']").html(this.downloadMenuItems(this.selectedThumbData));

  if (shouldShowInfo) {
    // spacer shows up when info doesn't.
    this.showUiElement(document.querySelector('#viewer-member-info'));
    this.hideUiElement(document.querySelector('#viewer-spacer'));
  } else {
    this.hideUiElement(document.querySelector('#viewer-member-info'));
    this.showUiElement(document.querySelector('#viewer-spacer'));
  }

  // show/hide next/prev as appropriate
  if (humanIndex <= 1) {
    this.hideUiElement(document.querySelector("#viewer-left"));
  } else if ( this.totalCount != 1 ) {
    this.showUiElement(document.querySelector("#viewer-left"));
  }

  if (humanIndex >= this.totalCount) {
    this.hideUiElement(document.querySelector("#viewer-right"));
  } else if ( this.totalCount != 1 ) {
    this.showUiElement(document.querySelector("#viewer-right"));
  }

  this.setLocationUrl();
};

ScihistImageViewer.prototype.next = function() {
  var nextElement = $(this.selectedThumb).next().get(0);
  if (nextElement) {
    this.selectThumb(nextElement);
    this.scrollSelectedIntoView();
  }
};

ScihistImageViewer.prototype.prev = function() {
  var prevElement = $(this.selectedThumb).prev().get(0);
  if (prevElement) {
    this.selectThumb(prevElement);
    this.scrollSelectedIntoView();
  }
};

ScihistImageViewer.prototype.setLocationUrl = function() {
  var currentPath = location.pathname;
  var selectedID = this.selectedThumbData.memberId;

  var newPath;

  if (currentPath.match(this.viewerPathComponentRe)) {
    newPath = currentPath.replace(this.viewerPathComponentRe, '/viewer/' + encodeURIComponent(selectedID));
  } else if (currentPath.match(/\/$/)) {
    newPath = currentPath + 'viewer/' + encodeURIComponent(selectedID);
  } else {
    newPath = currentPath + '/viewer/' + encodeURIComponent(selectedID);
  }
  const url = new URL(location.href);
  url.pathname = newPath;
  history.replaceState({}, "", url.href);
};

ScihistImageViewer.prototype.removeLocationUrl = function() {
  if (location.pathname.match(this.viewerPathComponentRe)) {
    const url = new URL(location.href);
    url.pathname = url.pathname.replace(this.viewerPathComponentRe, '');

    history.replaceState({}, "", url.href);
  }
}

// Add query to current url as #q={query}
// using replaceState to avoid adding a history entry
ScihistImageViewer.prototype.storeQueryInUrl = function(query) {
  const currentUrl = new URL(location.href);
  const hashKeys = new URLSearchParams(
    currentUrl.hash.replace(/^\#/, "")
  )

  hashKeys.set("q", query);
  currentUrl.hash = hashKeys.toString();

  history.replaceState({}, "", currentUrl.href);
}

// remove query in #fragment in current url, using replaceState
// to avoid adding history entry
ScihistImageViewer.prototype.removeQueryInUrl = function() {
  const currentUrl = new URL(location.href);
  const hashKeys = new URLSearchParams(
    currentUrl.hash.replace(/^\#/, "")
  )

  hashKeys.delete("q");
  currentUrl.hash = hashKeys.toString();
  history.replaceState({}, "", currentUrl.href);
}

// retrieve bookmarked query from #fragment in url
ScihistImageViewer.prototype.getQueryInUrl = function() {
  const hashKeys = new URLSearchParams(
    new URL(location.href).hash.replace(/^\#/, "")
  )

  return hashKeys.get("q");
}

ScihistImageViewer.prototype.onKeyDown = function(event) {
  // If we're in a text input, nevermind, just do the normal thing
  // if it's escape key though, keep going, to let escape key still close dialog
  if (event.target.tagName == "INPUT" && event.which != 27) {
    return;
  }

  // If dropdown is showing and it has links (unlike our shortcut legend),
  // let it capture keyboard to select and activate links.
  if ($(".dropdown-menu:visible a").length > 0) {
    return;
  }

  // Otherwise, if a drop down is visible, still ignore ESC key,
  // to let it close the dropdown.
  if (event.which == 27 && $("#scihist-image-viewer-modal *[data-toggle='dropdown'][aria-expanded='true']").length > 0) {
    return;
  }

  // Many parts copied/modified from OSD source, no way to proxy to it directly.
  // This one expects a jQuery event.
  // https://github.com/openseadragon/openseadragon/blob/e81e30c81cd8be566a4c8011ad7f592ac1df30d3/src/viewer.js#L2414-L2499
  if ( !event.preventDefaultAction && !event.ctrlKey && !event.altKey && !event.metaKey ) {
        switch( event.which ){
          case 27: // ESC
              this.hide();
              event.stopPropagation();
              break;
          case 38://up arrow
              if ( event.shiftKey ) {
                  this.viewer.viewport.zoomBy(1.1);
              } else {
                  this.viewer.viewport.panBy(this.viewer.viewport.deltaPointsFromPixels(new OpenSeadragon.Point(0, -40)));
              }
              this.viewer.viewport.applyConstraints();
              event.stopPropagation();
              break;
          case 40://down arrow
              if ( event.shiftKey ) {
                  this.viewer.viewport.zoomBy(0.9);
              } else {
                  this.viewer.viewport.panBy(this.viewer.viewport.deltaPointsFromPixels(new OpenSeadragon.Point(0, 40)));
              }
              this.viewer.viewport.applyConstraints();
              event.stopPropagation();
              break;
          case 37://left arrow
              if (event.shiftKey) {
                // custom CHF, next doc
                this.prev();
              } else {
                this.viewer.viewport.panBy(this.viewer.viewport.deltaPointsFromPixels(new OpenSeadragon.Point(-40, 0)));
                this.viewer.viewport.applyConstraints();
              }
              event.stopPropagation();
              break;
          case 39://right arrow
              if (event.shiftKey) {
                // custom CHF, prev doc
                this.next();
              } else {
                this.viewer.viewport.panBy(this.viewer.viewport.deltaPointsFromPixels(new OpenSeadragon.Point(40, 0)));
                this.viewer.viewport.applyConstraints();
              }
              event.stopPropagation();
              break;
          case 190: // . or >
              this.next();
              event.stopPropagation();
              break;
          case 188: // , or <
              this.prev();
              event.stopPropagation();;
          case 187: // = or +
              this.viewer.viewport.zoomBy(1.1);
              this.viewer.viewport.applyConstraints();
              event.stopPropagation();
              break;
          case 189: // - or _
              this.viewer.viewport.zoomBy(0.9);
              this.viewer.viewport.applyConstraints();
              event.stopPropagation();
              break;
          case 48: // 0 or )
              this.viewer.viewport.goHome();
              this.viewer.viewport.applyConstraints();
              event.stopPropagation();
              break;
          case 87: //w or W
              if ( event.shiftKey ) {
                  this.viewer.viewport.zoomBy(1.1);
              } else {
                  this.viewer.viewport.panBy(this.viewer.viewport.deltaPointsFromPixels(new OpenSeadragon.Point(0, -40)));
              }
              this.viewer.viewport.applyConstraints();
              event.stopPropagation();
              break;
          case 83: //s or S
              if ( event.shiftKey ) {
                  this.viewer.viewport.zoomBy(0.9);
              } else {
                  this.viewer.viewport.panBy(this.viewer.viewport.deltaPointsFromPixels(new OpenSeadragon.Point(0, 40)));
              }
              this.viewer.viewport.applyConstraints();
              event.stopPropagation();
              break;
          case 65://a
              this.viewer.viewport.panBy(this.viewer.viewport.deltaPointsFromPixels(new OpenSeadragon.Point(-40, 0)));
              this.viewer.viewport.applyConstraints();
              event.stopPropagation();
              break;
          case 68: // d or D
              this.viewer.viewport.panBy(this.viewer.viewport.deltaPointsFromPixels(new OpenSeadragon.Point(40, 0)));
              this.viewer.viewport.applyConstraints();
              event.stopPropagation();
              break;
          default:
              return true;
        }
    } else {
        return true;
    }
};


// We use the bootstrap modal, because it already handles
// tricky issues of full-body scroll and tabindex. We need to
// restyle some of it in CSS to be full-screen.
ScihistImageViewer.prototype.initModal = function(modalElement) {
  this.modal = modalElement;
  this.modal = $(this.modal).modal({
    show: false,
    keyboard: false
  });

  this.workId = modalElement.getAttribute("data-work-id");
  this.searchPath = modalElement.getAttribute("data-search-path");

  if (this.searchPath) {
    //If it's searchable, expose the search toggle
    this.modal.find("*[data-trigger='viewer-open-search']").removeClass("d-none");
  }

  var _self = this;
  var imageInfoUrl = modalElement.getAttribute("data-images-info-path");
  // This promise should be used in #show to make sure we don't until this
  this.thumbsLoadedGuard = fetch(imageInfoUrl, {
    credentials: 'include'
  }).then(function(response) {
    if(response.ok) {
      return response.json();
    }
    // non-200, something is bad.
    throw new Error(response.status + ': ImageViewer could not fetch image info from: ' + imageInfoUrl);

  }).then(function(json) {
    _self.totalCount = json.length;

    _self.pageInfo = new ViewerPageInfo(json);


    _self.makeThumbnails(json);
  });
};

// From json data describing our images, make the thumbnail sidebar
ScihistImageViewer.prototype.makeThumbnails = function(json) {
  var _self = this;

  var container = $(this.modal).find("#viewer-thumbs");
  $.each(json, function(index, config) {
    if (! config) {
      return;
    }

    const calcPixelHeight = (_self.thumbWidth / config.thumbAspectRatio).toFixed(1);
    // not totally sure if this forced height is really necessary currently, maybe in collapsed horizontal mode?
    // Need aspect-ratio to reserve proper space even before img is loaded, esp with lazy loading
    const inlineStyles = 'height:' + calcPixelHeight + 'px; aspect-ratio: ' + config.thumbAspectRatio + ';';

    container.append(
      '<button type="button" class="viewer-thumb"' +
        ' data-member-id="' + config.memberId + '"' +
        ' data-trigger="change-viewer-source"' +
        ' data-index="' + index + '"' +
      '>' +
        '<img ' +
              ' alt="Image ' + (index + 1) + '"' +
              ' data-base-alt="Image ' + (index + 1) + '"' +
              ' loading="lazy" ' +
              ' src="' + config.thumbSrc + '"' +
              ' srcset="' +  (config.thumbSrcset || '') + '"' +
              ' style="' + inlineStyles + '"' +

        '>' +
      '</button>'
    );
  });
};

ScihistImageViewer.prototype.downloadMenuItems = function(thumbData) {
  var _self = this;

  var htmlElements = []

  htmlElements = htmlElements.concat(
    $.map(thumbData.downloads, function(downloadElement) {
      if (! downloadElement.url) {
        return '<div class="px-4 text-muted text-small">' + downloadElement.label + '</div>';
      }


      return  '<a class="dropdown-item" target="_new" data-analytics-category="Work"' +
                ' data-analytics-action="' + (downloadElement.analyticsAction || "download") + '"' +
                ' data-analytics-label="' + _self.workId + '"' +
                ' href="' + downloadElement.url + '">' +
                  downloadElement.label +
                ' <small>' + (downloadElement.subhead || '') + '</small>' +
              '</a>';
    })
  );

  return htmlElements;
};

ScihistImageViewer.prototype.initOpenSeadragon = function() {
  // we only want a rotate-right, not rotate-left. Can't figure
  // out how to get OSD to do that, and not try to fetch rotate-left
  // images, except giving it a fake rotate-left
  // button, sorry!
  var dummyRotateLeft = document.createElement("div");
  dummyRotateLeft.id ='dummy-osd-rotate-left';
  dummyRotateLeft.style.display = 'none';
  document.body.appendChild(dummyRotateLeft);

  this.viewer = OpenSeadragon({
    id:            'openseadragon-container',
    showRotationControl: true,
    showFullPageControl: false,

    // we use our own controls
    zoomInButton:       "viewer-zoom-in",
    zoomOutButton:      "viewer-zoom-out",
    homeButton:         "viewer-zoom-fit",
    rotateRightButton:  "viewer-rotate-right",
    rotateLeftButton:   "dummy-osd-rotate-left",

    tabIndex: "",

    zoomPerClick: "1.5", // default 2, zoom slower

    preserveImageSizeOnResize: true,

    gestureSettingsTouch: {
      pinchRotate: false
    }
  });

  // OSD seems to insist on setting inline style position:relative on it's
  // own container. If we just change that to 'absolute', then it properly fills
  // the space of it's container on our page the way we want it to. There
  // must be a better way to do this, sorry for the hack.
  this.viewer.container.style.position = "absolute";

  // The OSD 'open' event is fired when it tries to request an image,
  // but hasn't neccesarily received it yet. Riiif can be really slow.
  // The first 'tile-drawing' event means we've actually got _something_
  // to paint on screen, better later point to remove spinner.
  var _self = this;
  this.viewer.addHandler("tile-drawing", function() {
    _self.removeLoading()
  } );
  this.viewer.addHandler("open-failed", function(event) {
    // Try fallback URL if available
    var fileId = _self.selectedThumbData.memberId;
    var fallbackOsdOpenArg = _self.selectedThumbData.fallbackTileSource;
    if (fallbackOsdOpenArg && fallbackOsdOpenArg !==  event.source) {
      _self.displayAlert("Sorry, full zooming is not currently available.")
      _self.viewer.open(fallbackOsdOpenArg);
    } else {
      // This doesn't seem to succesfully remove image, alas.
      _self.viewer.close();
      _self.displayAlert("Could not load image!");
    }
  });
  // If we haven't loaded a single tile yet, and get a tile-load-failed, error message
  // and no spinner.
  this.viewer.addHandler("tile-load-failed", function(event) {
    if (_self.loadingSpinnerDisplayed) {
      _self.viewer._showMessage("Tile load failed: " + event.message + ": " + event.tile.url);
      _self.removeLoading();
    }
  });


  // When a new page is loaded
  this.viewer.addHandler("open", function(event) {
    // Add gray border for white-edged images, usually born-digital pages
    _self.addBorderIfNeeded();

    // we add search results overlays
    _self.highlightSearchResults();

    // And keep consistent zoom level
    if (_self.restoreZoomValue) {
      var zoomToRefPoint;
      if (_self.restoreZoomValue <= _self.viewer.viewport.getHomeZoom()) {
        // entirely fits on screen, center it in viewport
        zoomToRefPoint = new OpenSeadragon.Point(0.5, 0.5);
      } else {
        // too big to fit on screen, align top with top, center horizontally
        zoomToRefPoint = new OpenSeadragon.Point(0.5, 0);
      }

      // put top left corner in top left corner?
      _self.viewer.viewport.zoomTo(_self.restoreZoomValue, zoomToRefPoint, true);

      _self.restoreZoomValue = undefined;
    }

    // If we have a current search result that's off screen, pan there
    _self.ensureCurrentResultVisible(true);

  });
};

ScihistImageViewer.prototype.addBorderIfNeeded = function() {
  if (this.selectedThumbData.whiteEdge) {
    const elt = document.createElement("div");
    elt.className = "viewer-page-border";
    this.viewer.addOverlay({
      element: elt,
      location: new OpenSeadragon.Rect(0, 0, 1, this.viewer.world.getItemAt(0).getBounds().height)
    });
  }
}

ScihistImageViewer.prototype.highlightSearchResults = function() {
  const currentMemberId = this.selectedThumbData?.memberId;

  const resultOverlaysForPage = this.searchResults?.resultsByPageId( currentMemberId );

  if (resultOverlaysForPage) {
    for (let result of resultOverlaysForPage) {
      let elt = document.createElement("div");
      elt.className = "viewer-search-highlight";
      elt.id = result.result_id;

      // the bounding box is EXACTLY where OCR thinks letters stop/start. Making
      // the highlight a bit bigger looks better. let's say 1/6th of (line) height padding
      const padding = result.osd_rect.height / 6;
      const left = result.osd_rect.left - padding;
      const top = result.osd_rect.top - padding;
      const width = result.osd_rect.width + (padding * 2);
      const height = result.osd_rect.height + (padding * 2);

      this.viewer.addOverlay({
          element: elt,
          location: new OpenSeadragon.Rect(left, top, width, height)
      });
    }

    this.setSelectedHighlight();
  }
}

// The .viewer-search-highlight OCR highlight div for the current result
// gets a custom class which also has an initial animation
ScihistImageViewer.prototype.setSelectedHighlight = function() {
  $(".viewer-search-highlight").removeClass("selected-search-highlight");

  if (this.currentSearchResult) {
    $("#" + this.currentSearchResult.result_id).addClass("selected-search-highlight");
  }
}

// If we have a current search result that's off screen, pan there
//
// @param immediate {Boolean} suppress pan animation, jump immediately
ScihistImageViewer.prototype.ensureCurrentResultVisible = function(immediate = false) {
  if (this.currentSearchResult) {
    const viewportBounds = this.viewer.viewport.getBounds();

    // TODO make this a function in currentSearchResult please, so we can add rotate later
    const resultBox      = new OpenSeadragon.Rect(
      this.currentSearchResult.osd_rect.left,
      this.currentSearchResult.osd_rect.top,
      this.currentSearchResult.osd_rect.height,
      this.currentSearchResult.osd_rect.width
    ).getBoundingBox();

    if (! (viewportBounds.containsPoint(resultBox.getTopLeft()) && viewportBounds.containsPoint(resultBox.getBottomRight()))) {
      this.viewer.viewport.panTo( resultBox.getCenter(), immediate);
    }
  }
}




ScihistImageViewer.prototype.hideUiElement = function(element) {
  element.style.display = "none";
};

ScihistImageViewer.prototype.showUiElement = function(element) {
  element.style.display = "";
};

ScihistImageViewer.prototype.displayAlert = function(msg) {
  var alertHtml = '<div class="viewer-alert alert alert-warning alert-dismissible" role="alert">' +
                  '    <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>' +
                  '    <i class="fa fa-exclamation-triangle" aria-hidden="true"></i> ' +
                       msg +
                  '</div>';

  var container = document.querySelector("*[data-alert-container]");

  container.insertAdjacentHTML('afterbegin', alertHtml);
}

ScihistImageViewer.prototype.getSearchResults = async function(query) {
  const searchResultsContainer = document.querySelector(".viewer-search-area .search-results-container");

  try {
    this.clearSearchResults();

    searchResultsContainer.innerHTML = "<div class='viewer-results-loading'></div><p class='text-center'>Searching...</p>";

    const searchUrl = new URL(this.searchPath, window.location);
    searchUrl.searchParams.append("q", query);

    const searchResponse = await fetch(searchUrl);
    const searchResults  = await searchResponse.json();

    if (! searchResponse?.ok) {
      throw new Error(searchResults?.error)
    }

    searchResultsContainer.innerHTML = "";
    this.storeQueryInUrl(query);
    this.currentSearchQuery = query;

    if (searchResults.length == 0) {
      searchResultsContainer.innerHTML = "<p>No results found.</p>";
      return;
    }


    // set searchResultsObject
    this.searchResults = new ViewerSearchResults(searchResults, this.pageInfo);

    document.getElementById("searchNavLabel").textContent = this.searchResults.resultsCountMessage();
    document.getElementById("searchNav").style.display = "flex";

    // For each search result, we need to render it in results
    for (const result of this.searchResults.jsonResults()) {
      const id = result['member_id'];

      const resultHtml = document.createElement('a');
      resultHtml["href"] = "#";
      resultHtml.setAttribute('data-search-result-index', result['resultIndex']);
      resultHtml.setAttribute('data-trigger', 'viewer-search-result');
      resultHtml.className = "result";
      resultHtml.innerHTML = result.text;
      searchResultsContainer.append(resultHtml)
    }

    // show highlights on current page if it's already open. otherwise
    // highlights will be triggered in our open callback, and we don't want to
    // double render.
    if (this.viewer.isOpen()) {
      this.highlightSearchResults();
    }

    // Highlight thumbs in thumblist with result count. Add data attribute,
    // CSS will take care of rest.
    for (const [memberId, results] of Object.entries(this.searchResults.allResultsByPageId())) {
      const elt = document.querySelector(".viewer-thumb[data-member-id='" + memberId + "']");
      const imgElt = elt.querySelector("img");

      elt.setAttribute("data-search-result-count", results.length);
      imgElt.setAttribute("alt", imgElt.getAttribute("data-base-alt") + " (" + results.length + " results)");
    }
  } catch (error) {
    console.log("scihist_viewer, error fetching search results: " + error.message);
    searchResultsContainer.innerHTML = "<p class='alert alert-danger' role='alert'>\
      <i class='fa fa-exclamation-triangle' aria-hidden='true'></i>\
      Sorry, our system experienced a problem and could not provide search results.\
    </p>";
    throw error;
  }
};

ScihistImageViewer.prototype.selectSearchResult = function(resultElement) {
  // Add class for highlighting search result, removing from any others
  $(".result.current-viewer-result").removeClass("current-viewer-result")
  $(resultElement).addClass("current-viewer-result");
  this.scrollElementIntoView(resultElement);

  const searchResultIndex = parseInt( resultElement.getAttribute('data-search-result-index') );
  const resultData = this.searchResults.resultByIndex(searchResultIndex)

  this.currentSearchResult = resultData;
  document.getElementById("searchNavLabel").textContent = `${ searchResultIndex + 1 } / ${ this.searchResults.resultsCount()}`

  const memberId = resultData['member_id'];

  if (memberId != this.selectedThumbData.memberId) {
    const thumbElement = this.findThumbElement(memberId);
    this.selectThumb(thumbElement, { resetCurrentSearchResult: false });
    this.scrollSelectedIntoView();
  } else {
    // If we have a current search result that's off screen, pan there
    this.ensureCurrentResultVisible();

    // And make sure current highlight is styled
    this.setSelectedHighlight();
  }
}

ScihistImageViewer.prototype.clearSearchResults = function() {
  const searchResultsContainer = document.querySelector(".viewer-search-area .search-results-container");

  document.getElementById("searchNav").style.display = "none";

  document.querySelectorAll(".viewer-thumb[data-search-result-count]").forEach(function(el) {
    el.removeAttribute("data-search-result-count");

    const imgElt = el.querySelector("img");
    imgElt.setAttribute("alt", imgElt.getAttribute("data-base-alt"));
  });

  this.viewer.clearOverlays();
  this.removeQueryInUrl();
  this.currentSearchQuery = undefined;
  this.currentSearchResult = undefined;
  searchResultsContainer.innerHTML = "";
  this.searchResults = undefined;
}

ScihistImageViewer.prototype.showSearchDrawer = function() {
  this.modal.find("*[data-trigger='viewer-open-search']").addClass("d-none");
  this.modal.find('.viewer-search-area').addClass("slid-in drawer-visible");
  // focus on input, important accessibility
  this.modal.find('.viewer-search-area').find("#q").get(0).focus();
}

ScihistImageViewer.prototype.hideSearchDrawer = function() {
  this.modal.find('.viewer-search-area').removeClass("slid-in");
  this.modal.find("*[data-trigger='viewer-open-search']").removeClass("d-none");
  // put focus on search toggle, good for accessibility to make sure focus is somewhere
  this.modal.find('.viewer-search-open').focus();

  // after duration, remove visibility for accessibilty, duration needs to match
  // our animation length.
  // https://knowbility.org/blog/2020/accessible-slide-menus
  const _self = this;
  setTimeout(function() {
    _self.modal.find('.viewer-search-area').removeClass("drawer-visible");
  }, 500);
}

ScihistImageViewer.prototype.nextSearchResult = function() {
  let gotoIndex; // 0-based index into searchResults

  if (this.currentSearchResult) {
    gotoIndex = this.currentSearchResult.resultIndex + 1;
  } else {
    // find next one from current page.
    gotoIndex = this.searchResults.nextResultFromPageIndex(this.selectedThumbData.index)?.resultIndex;
  }

  // If we need to wrap around because we're too high or we didn't find one from current page,
  // wrap around to start
  if (gotoIndex == undefined || gotoIndex >= this.searchResults.resultsCount()) {
    gotoIndex = 0;
  }

  const resultElement = document.querySelector(`.search-results-container *[data-search-result-index='${gotoIndex}']`);
  this.selectSearchResult(resultElement);
}

ScihistImageViewer.prototype.previousSearchResult = function() {
  let gotoIndex; // 0-based index into searchResults

  if (this.currentSearchResult) {
    gotoIndex = this.currentSearchResult.resultIndex - 1;
  } else {
    gotoIndex = this.searchResults.previousResultFromPageIndex(this.selectedThumbData.index)?.resultIndex;
  }

  // if we need to wrap around because we're too low or we didn't find one, wrap around
  // to last result.
  if (gotoIndex == undefined || gotoIndex < 0) {
    gotoIndex = this.searchResults.resultsCount() - 1;
  }

  const resultElement = document.querySelector(`.search-results-container *[data-search-result-index='${gotoIndex}']`);
  this.selectSearchResult(resultElement);
}

jQuery(document).ready(function($) {
  if ($("*[data-trigger='scihist_image_viewer']").length > 0) {
    // lazily create a single page-wide ScihistImageViewer helper
    var _chf_image_viewer;
    var chf_image_viewer = function() {
      if (typeof _chf_image_viewer == 'undefined') {
        _chf_image_viewer = new ScihistImageViewer();
        window.chf = _chf_image_viewer;
      }

      return _chf_image_viewer;
    };


    // Do we have a viewer search form on a work page, and a preserved
    // main query in the current URL anchor to pre-fill it?
    const currentUrl = new URL(location.href);
    const hashKeys = new URLSearchParams(
      currentUrl.hash.replace(/^\#/, "")
    );
    const queryFromUrl = hashKeys.get("prevq");

    if(queryFromUrl) {
      const searchInput = document.querySelector("#search-inside-q");
      if (searchInput && searchInput.value == "") {
        searchInput.value = queryFromUrl;
      }

      // AND remove it to provide a clean URL
      hashKeys.delete("prevq");
      currentUrl.hash = hashKeys.toString();
      history.replaceState({}, "", currentUrl.href);
    }

    var viewerUrlMatch = ScihistImageViewer.prototype.viewerPathComponentRe.exec(location.pathname);
    if (viewerUrlMatch != null) {
      // we have a viewer thumb in URL, let's load the viewer on page load!
      chf_image_viewer().show(viewerUrlMatch[1]);
    }

    // Record whether dropdown is showing, so we can avoid keyboard handling
    // for viewer when it is, let the dropdown have it. Prob better to
    // do this with jquery on/off, but this was easiest for now.
    $(chf_image_viewer().modal).on("show.bs.dropdown", function(event) {
      chf_image_viewer().dropdownVisible = true;
    });
    $(chf_image_viewer().modal).on("hide.bs.dropdown", function(event) {
      chf_image_viewer().dropdownVisible = false;
    });


    $(document).on("click", "*[data-trigger='scihist_image_viewer']", function(event) {
      event.preventDefault();
      var id = this.getAttribute('data-member-id');
      chf_image_viewer().show(id);
    });

    // with keyboard-tab nav to our thumbs, let return/space trigger click as for normal links
    $(document).on("keydown", "*[data-trigger='scihist_image_viewer']", function(event) {
      // space or enter trigger click for keyboard control
      if (event.which == 13 || event.which == 32) {
        event.preventDefault();
        $(this).trigger("click");
      }
    });

    $(document).on("click", "*[data-trigger='scihist_image_viewer_close']", function(event) {
      event.preventDefault();
      chf_image_viewer().hide();
    });

    $(document).on("click", "*[data-trigger='change-viewer-source']", function(event) {
      event.preventDefault();
      chf_image_viewer().selectThumb(this);
    });

    $("body").on("keypress", "*[data-trigger='change-viewer-source']", function(event) {
      // space or enter trigger click for keyboard control
      if (event.which == 13 || event.which == 32) {
        event.preventDefault();
        $(this).trigger("click");
      }
    });

    $(document).on("click", "*[data-trigger='viewer-next']", function(event) {
      event.stopPropagation();
      chf_image_viewer().next();
    });

    $(document).on("click", "*[data-trigger='viewer-prev']", function(event) {
      event.stopPropagation();
      chf_image_viewer().prev();
    });

    $(document).on("click", "*[data-trigger='viewer-fullscreen']", function(event) {
      // Use OSD's cross-browser fullscreen implementation, great.
      if (OpenSeadragon.isFullScreen()) {
        OpenSeadragon.exitFullScreen();
      } else {
        OpenSeadragon.requestFullScreen( document.body );
      }
    });

    $(document).on("submit", "*[data-trigger='viewer-search']", function(event) {
      event.preventDefault();

      const query = $(event.target).find("input").val();
      if (query.trim() != "") {
        chf_image_viewer().getSearchResults( query );
      }
    });

    // Search that's on main work page, before viewer is opened
    $(document).on("submit", "*[data-trigger='show-viewer-search']", function(event) {
      event.preventDefault();

      const query = $(event.target).find("input").val();
      if (query.trim() != "") {
        chf_image_viewer().show();
        chf_image_viewer().showSearchDrawer();
        chf_image_viewer().modal.find("#q").val(query); // set in search box in viewer
        chf_image_viewer().getSearchResults( query ).then(function() {
          // and go to first result if we have one, kinda hacky way to do it with
          // DOM element
          // hash
          const firstSearchResult = chf_image_viewer().modal.find(".search-results-container .result").get(0);
          if (firstSearchResult) {
            chf_image_viewer().selectSearchResult(firstSearchResult);
          }
        });
      }
    });

    $(document).on("click", "*[data-trigger='viewer-search-result']", function(event) {
      event.preventDefault();

      chf_image_viewer().selectSearchResult(event.currentTarget);
    });

    $(document).on("click", "*[data-trigger='clear-search-results']", function(event) {
      event.target.closest("*[data-trigger='viewer-search']").querySelector("#q").value = '';
      chf_image_viewer().clearSearchResults();
    });

    $(document).on("click", "*[data-trigger='viewer-open-search']", function(event) {
      chf_image_viewer().showSearchDrawer();
    });

    $(document).on("click", "*[data-trigger='viewer-close-search']", function(event) {
      chf_image_viewer().hideSearchDrawer();
    });

    $(document).on("click", "*[data-trigger='viewer-result-next']", function(event) {
      chf_image_viewer().nextSearchResult();
    });

    $(document).on("click", "*[data-trigger='viewer-result-previous']", function(event) {
      chf_image_viewer().previousSearchResult();
    });
  }
});
