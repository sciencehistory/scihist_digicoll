// In progress, may extract to kithe, needs more docs.

// Began with shrine example at https://github.com/erikdahlstrand/shrine-rails-example/blob/cbf2916836c54e02bdf4d35d8c8e0ee487e93eb5/app/assets/javascripts/application.js
// but this is pretty different, using uppy 'dashboard', and a more sufia/hyrax-like ui,
// with a file list of direct uploaded files.

// This code uses uppy (https://uppy.io), and will also need promise/fetch polyfills for IE11, eg:
//
// * promise polyfill (https://github.com/taylorhakes/promise-polyfill)
// * whatwg-fetch (https://github.github.io/fetch/)
//
// If you aren't using webpacker or other ES6 toolchain, easiest thing to do is simply
// include them in script tags, although that includes all of uppy when only some is needed.

// hide everything in a closure for better or worse
(function() {
  function kithe_createFileUploader(container) {
    // Some variables that can be taken from data- attributes, or defaults.
    var uploadEndpoint   = container.getAttribute("data-upload-endpoint");
    var dashboardWidth   = container.getAttribute("data-dashboard-width") || "auto";
    var dashboardHeight  = container.getAttribute("data-dashboard-height") || "400px";
    var uppyRestrictions = container.getAttribute("data-uppy-restrictions");
    var s3Storage        = container.getAttribute("data-s3-storage");
    var s3StoragePrefix  = container.getAttribute("data-s3-storage-prefix");

    if (uppyRestrictions) {
      uppyRestrictions = JSON.parse(uppyRestrictions);
    }

    var closest = function(el, fn) {
      return el && (fn(el) ? el : closest(el.parentNode, fn));
    }

    var containerForm = closest(container, function(el) { return el.tagName.toLowerCase() == "form" });
    var cachedFileTableEl = containerForm.querySelector("*[data-toggle='cached-files-table']");
    var directoryInput = containerForm.querySelector("*[data-toggle='directory-input']");
    var browseEverythingButton = containerForm.querySelector('*[data-toggle="kithe-browse-everything"]');
    var submitButton = containerForm.querySelector("*[data-toggle='kithe-upload-submit']");

    var uppy = Uppy.Core({
        id: container.id,
        autoProceed: true,
        restrictions: uppyRestrictions
      })
      .use(Uppy.Dashboard, {
        inline: true,
        target: container,
        replaceTargetContent: true,
        showProgressDetails: true,
        hidePauseResumeButton: false,
        width: dashboardWidth,
        height: dashboardHeight, // won't actually let us go smaller than 400 https://github.com/transloadit/uppy/pull/1128
        // We have really large files that could take a while, plus plenty of files
        // uppy can't get thumbs for anyway.
        disableThumbnailGenerator: true,
      })


    // S3 mode still a work in progress.
    if (s3Storage) {
      uppy.use(Uppy.AwsS3Multipart, {
        serverUrl: (uploadEndpoint || '/'), // will call Shrine's presign endpoint mounted on `/s3/params`
        abortMultipartUpload: function(file, options) {
          // no-op, we don't want uppy trying to delete, which it does on removeFile,
          // which we use to remove completed files from dashboard. See:
          // https://github.com/transloadit/uppy/issues/1164
        }
      })
    } else {
      uppy.use(Uppy.XHRUpload, {
        endpoint: (uploadEndpoint || "/direct_upload"), // Shrine's upload endpoint
        fieldName: 'file'
      })
    }

    // turns a number of bytes into human readable eg "12GB"
    // https://stackoverflow.com/a/38897674
    var fileSizeSI = function(size) {
      var e = (Math.log(size) / Math.log(1e3)) | 0;
      return +(size / Math.pow(1e3, e)).toFixed(1) + ' ' + ('kMGTPEZY'[e - 1] || '') + 'B';
    }

    // Returns the <input type="hidden"> representing a direct-uploaded
    // file, to be sent to controller for attachment. Value will be a JSON
    // serialization of the hash describing the uploaded-to-cache file,
    // to be sent to the controller.
    var makeHiddenFieldForCachedFile = function(shrineHash) {
      var hidden = document.createElement("input");
      hidden.setAttribute("type", "hidden");
      hidden.setAttribute("name", "cached_files[]");
      hidden.setAttribute("value", JSON.stringify(shrineHash));

      return hidden;
    }

    // create a DOM element for a table row that will be the list of succesfully
    // direct uploaded files, including hidden inputs to be submitted with form,
    // and a remove button to remove it from list.
    //
    // With just browser API, yeah, it's a bit ugly code.
    var makeCachedFileRow = function(shrineHash) {
      var row = document.createElement("tr");

      var firstCell = row.appendChild(document.createElement("td"));
      firstCell.appendChild(makeHiddenFieldForCachedFile(shrineHash));
      firstCell.appendChild(document.createTextNode(shrineHash.metadata.filename));

      if (shrineHash.metadata.size) {
        var size = fileSizeSI(shrineHash.metadata.size);
      } else {
        var size = "";
      }

      row.appendChild(document.createElement("td")).innerText = size;
      row.appendChild(document.createElement("td")).innerHTML =
        "<button type='button' data-cached-file-remove='true' class='btn btn-outline-primary'>Remove</button>";

      return row;
    }


    // When a file is fully direct uploaded by uppy, we remove it from uppy dashboard,
    // and instead list it in our list of files to be attached on form submit.
    uppy.on("upload-success", function(file, response) {
      var shrineHash;
      if (s3Storage) {
        var url = new URL(response.uploadURL);
        var shrineId = url.pathname.replace(/^\//, '') // remove leading slash on pathname

        if (s3StoragePrefix) {
          // object key is path on s3, but without the configured shrine storage prefix,
          // get the part after our storage prefix.
          var s3StoragePrefixNoTrailingSlash = s3StoragePrefix.replace(/\/$/, "");
          shrineId = shrineId.match(new RegExp('^' + s3StoragePrefixNoTrailingSlash + '\/([^\?]+)'))[1];
        }

        shrineHash = {
          id: shrineId,
          storage: s3Storage,
          metadata: {
            size:      file.size,
            filename:  file.name,
            mime_type: file.type,
          }
        }
      } else {
        shrineHash = response.body;
      }

      // add the file to our list that will be submitted with form
      cachedFileTableEl.appendChild(makeCachedFileRow(shrineHash));

      // And remove from uppy dashboard, we're treating that just as the in-progress
      // list. This means we won't get a `complete` callback though. :(
      uppy.removeFile(file.id);
    });

    // Make the remove button work on the cached file rows
    cachedFileTableEl.addEventListener('click', function(event) {
      if (event.target.getAttribute("data-cached-file-remove")) {
        row = closest(event.target, function(el) { return el.tagName.toLowerCase() == "tr" });
        row.parentNode.removeChild(row);
      }
    });

    var handleDirectoryInput = function() {
      var fileList = this.files;
      for (var i = 0; i < fileList.length; i++) {
        var file = fileList[i];
        uppy.addFile({
          name: file.name, // file name
          type: file.type, // file type
          data: file, // file blob
        });

        // Would be nice to remove files from html input, but it messes things up.
        // We gave it no `name` so it shouldn't submit with form or anything.
        //this.value = ""; // remove files from html input?
      }
    }

    if (directoryInput) {
      directoryInput.addEventListener("change", handleDirectoryInput, false);
    }

    // Pretty hacky and not great way to try to disable submit button
    // when uploads are in progress.  https://github.com/transloadit/uppy/issues/1152

    // kind of cribbed from uppy code
    // https://github.com/transloadit/uppy/blob/714a2373e89c74ca6ff761e1f2587e7eeaa34c98/packages/%40uppy/dashboard/src/index.js#L555-L562
    // But changed, we remove files from dashboard on succesful completion, so any files
    // still in there unless they have an error can generally be considered non-complete files.
    var hasNonFinishedFiles = function() {
      var files = uppy.getState().files;
      var nonFinishedFiles = Object.keys(files).filter(function(file) {
        return !files[file].progress.uploadComplete &&
               !files[file].error
        });
      return nonFinishedFiles.length != 0;
    };

    var uploadInProgress = false;
    var updateUiForProgress = function() {
      var foundNonFinished = hasNonFinishedFiles();
      if (foundNonFinished != uploadInProgress) {
        uploadInProgress = foundNonFinished;

        if (submitButton) {
          if (uploadInProgress) {
            submitButton.setAttribute("disabled", true);
          } else {
            submitButton.removeAttribute("disabled");
          }
        }

        if (directoryInput && !uploadInProgress) {
          // try zero-ing out the html file input, so mouseover won't show
          // a list of files that we already processed and added to hidden inputs
          directoryInput.value = "";
        }
      }
    };
    // doing way too much work on too many events, but we know we catch them all in
    // various weird circumstances.
    uppy.on("complete", function(file) {
      updateUiForProgress();
    });
    uppy.on("upload", function(file) {
      updateUiForProgress();
    });
    uppy.on("upload-error", function(file, error) {
      updateUiForProgress();
    });
    uppy.on("file-removed", function(file) {
      updateUiForProgress();
    });

    if (browseEverythingButton) {
      // We can use JQuery, browse-everything needs it anyway. for some reason didn't
      // work without jquery ready. :(
      $( document ).ready(function() {
        $(browseEverythingButton).browseEverything().done(function(data) {
          data.forEach(function(item) {
            // Need to turn b-e results into a proper hash for shrine
            var shrineHash = {
              "storage": "remote_url",      // hard-coded kithe storage name
              "id": item.url,               // shrine-url storage takes url here
              "expires": item.expires,      // not used by back end, but we'll still send it
              "headers": item.auth_header,  // shrine-url storage can use
              "metadata": {
                "filename": item.file_name, // standard shrine
              }
            };
            cachedFileTableEl.appendChild(makeCachedFileRow(shrineHash));
          });
        });
      });
    }

    return uppy;
  }

  function ready(fn) {
    if (document.attachEvent ? document.readyState === "complete" : document.readyState !== "loading"){
      fn();
    } else {
      document.addEventListener('DOMContentLoaded', fn);
    }
  }
  ready(function() {
    document.querySelectorAll('*[data-toggle="kithe-upload"]').forEach(function (container) {
      kithe_createFileUploader(container);
    })
  });
})();
