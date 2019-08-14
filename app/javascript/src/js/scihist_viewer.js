// A JS 'class' for dealing with the image viewer.
//
//   * Depends on JQuery being available, although not imported webpacker style
//   * Depends on Bootstrap modal JS being available, although not imported webpacker style
//   * Depends on lazysizes.js (we load in separate webpack, so no "import")
//
// Image viewer is triggered with an <a> tag with these data attributes:
//
//   * data-trigger='scihist_image_viewer' : triggers viewer
//   * data-member-id=[friendly_id]: optional, ID of member (from data-images-info-path data) to select in viewer.
//
// Assumes a bootstrap modal for viewer is available at DOM id #scihist-image-viewer-modal, it has to have
// a data-work-id and data-images-info-path (URL to JSON images info) for the work. Yes, that means
// right now we assume on a given page, a viewer will only be displayed for ONE single work. data-images-info-path
// is a URL that will return JSON, see ViewerMemberInfoSerializer for what it looks like.
//
// Note the viewer updates the URL to add a "viewer/[memberId]" reference, so you can bookmark or link to viewer open
// to certain member. Routes need to route that to ordinary show page, let JS pick up the end of the path.

import OpenSeadragon from 'openseadragon';

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
      selectedThumb = document.querySelector(".viewer-thumb-img[data-member-id='" + id + "']");
    }
    if (! selectedThumb) {
      // just use the first one
      selectedThumb = document.querySelector(".viewer-thumb-img");
    }
    _self.selectThumb(selectedThumb);

    // show the viewer
    $(_self.modal).modal("show");
    _self.scrollSelectedIntoView();

    // Catch keyboard controls
    $("body").on("keydown.chf_image_viewer", function(event) {
      _self.onKeyDown(event);
    });
  });
};

// position can be 'start', 'end'
ScihistImageViewer.prototype.scrollSelectedIntoView = function(position) {
  // only if the selected thing is not currently in scroll view, scroll
  // it to be so.
  // https://stackoverflow.com/a/16309126/307106

  var elem = this.selectedThumb;

  var container = $(".viewer-thumbs");

  var contHeight = container.height();
  var contTop = container.scrollTop();
  var contBottom = contTop + contHeight ;

  var contWidth = container.width();
  var contLeft = container.scrollLeft();
  var contRight = contLeft + contWidth;


  var elemTop = $(elem).offset().top - container.offset().top;
  var elemBottom = elemTop + $(elem).height();
  var elemLeft = $(elem).offset().left - container.offset().left;
  var elemRight = elemLeft + $(elem).width();

  var isTotal = (elemTop >= 0 && elemBottom <= contHeight && elemLeft >= 0 && elemRight <= contWidth);

  if (! isTotal) {
    if (position == "end") {
      this.selectedThumb.scrollIntoView(false);
    } else {
      this.selectedThumb.scrollIntoView();
    }
  }
}

ScihistImageViewer.prototype.hide = function() {
  if (OpenSeadragon.isFullScreen()) {
    OpenSeadragon.exitFullScreen();
  }

  $("body").off("keydown.chf_image_viewer");

  this.viewer.close();
  $(this.modal).modal("hide");
  this.removeLocationUrl();
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
  $('.viewer-image').addClass('viewer-image-loading');
}

ScihistImageViewer.prototype.removeLoading =  function() {
  if (this.loadingSpinnerDisplayed) {
    $('.viewer-image').removeClass('viewer-image-loading');
    this.loadingSpinnerDisplayed = false;
  }
};

ScihistImageViewer.prototype.selectThumb = function(thumbElement) {
  this.selectedThumb = thumbElement;

  var index = parseInt(thumbElement.getAttribute("data-index"));
  var humanIndex = index + 1;
  this.selectedThumbData = this.thumbnailData[index];

  // toggle classes
  $('.viewer-thumbs .viewer-thumb-selected').removeClass('viewer-thumb-selected')
  thumbElement.classList.add('viewer-thumb-selected');

  var id = this.selectedThumbData.memberId;
  var shouldShowInfo = this.selectedThumbData.memberShouldShowInfo;
  var title = this.selectedThumbData.title;
  var linkUrl = this.selectedThumbData.memberShowUrl;
  var tileSource = this.selectedThumbData.tileSource;

  // hide any currently visible alerts, they only apply to
  // previously current image.
  $(this.modal).find(".viewer-alert").remove();

  this.viewer.close();

  this.addLoading();

  this.viewer.open(tileSource);

  document.querySelector('*[data-hook="viewer-navbar-title-label"]').textContent = title;
  document.querySelector('*[data-hook="viewer-navbar-info-link"]').href = linkUrl;
  document.getElementsByClassName('viewer-pagination-numerator').item(0).textContent = humanIndex;

  $(this.modal).find("#viewer-download .dropdown-menu").html(this.downloadMenuItems(this.selectedThumbData));

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
    this.scrollSelectedIntoView("start");
  }
};

ScihistImageViewer.prototype.prev = function() {
  var prevElement = $(this.selectedThumb).prev().get(0);
  if (prevElement) {
    this.selectThumb(prevElement);
    this.scrollSelectedIntoView("end");
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

  history.replaceState({}, "", this.locationWithNewPath(newPath));
};

ScihistImageViewer.prototype.removeLocationUrl = function() {
  if (location.pathname.match(this.viewerPathComponentRe)) {
    var newPath = location.pathname.replace(this.viewerPathComponentRe, '');
    history.replaceState({}, "", this.locationWithNewPath(newPath));
  }
}

ScihistImageViewer.prototype.locationWithNewPath = function(newPath) {
  var newUrl = location.protocol + '//' + location.host + newPath;
  if (location.query) {
    newUrl += '?' + location.query;
  }
  if (location.hash) {
    newUrl += '#' + location.hash;
  }
  return newUrl;
};

ScihistImageViewer.prototype.onKeyDown = function(event) {
  // If dropdown is showing and it has links (unlike our shortcut legend),
  // let it capture keyboard to select and activate links.
  if ($(".dropdown-menu:visible a").length > 0) {
    return;
  }

  // Otherwise, if a drop down is visible, still ignore ESC key,
  // to let it close the dropdown.
  if (event.which == 27 && $("#chf-image-viewer-modal *[data-toggle='dropdown'][aria-expanded='true']").length > 0) {
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

  var rightsElement = modalElement.querySelector('.parent-rights-inline');
  if (rightsElement) {
    this.rightsInlineHtml = rightsElement.innerHTML;
  }

  var parentDownloadElements = modalElement.querySelector('.parent-download-options-inline');
  if (parentDownloadElements) {
    this.parentDownloadInlineHtml = parentDownloadElements.innerHTML;
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
    _self.makeThumbnails(json);
  });
};

// From json data describing our images, make the thumbnail sidebar
ScihistImageViewer.prototype.makeThumbnails = function(json) {
  var _self = this;
  _self.thumbnailData = json;
  var container = $(this.modal).find("#viewer-thumbs");
  $.each(json, function(index, config) {
    if (! config) {
      return;
    }

    var calcPixelHeight = (_self.thumbWidth / config.thumbAspectRatio).toFixed(1);

    container.append(
      '<img class="lazyload viewer-thumb-img"' +
            ' alt="" tabindex="0" role="button"' +
            ' data-member-id="' + config.memberId + '"' +
            ' data-trigger="change-viewer-source"' +
            ' data-src="' + config.thumbSrc + '"' +
            ' data-srcset="' +  (config.thumbSrcset || '') + '"' +
            ' data-index="' + index + '"' +
            ' style="height:' + calcPixelHeight + 'px;"' +
      '>'
    );
  });
};

ScihistImageViewer.prototype.downloadMenuItems = function(thumbData) {
  var _self = this;

  var htmlElements = []

  if (_self.rightsInlineHtml) {
    htmlElements.push('<li class="dropdown-header">Rights</li>');
    htmlElements.push('<li tabindex="-1" role="menuItem">' + _self.rightsInlineHtml + '</li>');
    htmlElements.push('<li role="separator" class="divider"></li>');
  }
  if (_self.parentDownloadInlineHtml) {
    htmlElements.push(_self.parentDownloadInlineHtml);
    htmlElements.push('<li role="separator" class="divider"></li>');
  }


  htmlElements.push('<li class="dropdown-header">Download selected image</li>');

  htmlElements = htmlElements.concat(
    $.map(thumbData.downloads, function(downloadElement) {
      return '<li tabindex="-1" role="menuitem">' +
                '<a target="_new" data-analytics-category="Work"' +
                ' data-analytics-action="' + (downloadElement.analyticsAction || "download") + '"' +
                ' data-analytics-label="' + _self.workId + '"' +
                ' href="' + downloadElement.url + '">' +
                  downloadElement.label +
                ' <small>' + (downloadElement.subhead || '') + '</small>' +
                '</a>' +
              '</li>';
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
      _self.removeLoading();
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

};

ScihistImageViewer.prototype.hideUiElement = function(element) {
  element.style.display = "none";
};

ScihistImageViewer.prototype.showUiElement = function(element) {
  element.style.display = "";
};

ScihistImageViewer.prototype.displayAlert = function(msg) {
  var alertHtml = '<div class="viewer-alert alert alert-warning alert-dismissible" role="alert">' +
                  '    <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>' +
                  '    <i class="fa fa-exclamation-triangle" aria-hidden="true"></i> ' +
                       msg +
                  '</div>';

  var container = document.querySelector("*[data-alert-container]");
  container.insertAdjacentHTML('beforebegin', alertHtml);
}



jQuery(document).ready(function($) {
  if ($("*[data-trigger='scihist_image_viewer']").length > 0) {
    // lazily create a single page-wide ScihistImageViewer helper
    var _chf_image_viewer;
    var chf_image_viewer = function() {
      if (typeof _chf_image_viewer == 'undefined') {
        _chf_image_viewer = new ScihistImageViewer();
      }

      return _chf_image_viewer;
    };

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
  }
});
