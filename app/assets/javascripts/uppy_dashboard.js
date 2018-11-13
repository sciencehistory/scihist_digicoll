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




function createUppyDashboard(container) {
  // Some variables that can be taken from data- attributes, or defaults.
  var localUploadEndpoint = container.getAttribute("data-local-upload-endpoint") || "/direct_upload";
  var dashboardWidth = container.getAttribute("data-dashboard-width") || "100%";
  var dashboardHeight = container.getAttribute("data-dashboard-height") || "400px";
  var uppyRestrictions = container.getAttribute("data-uppy-restrictions");
  if (uppyRestrictions) {
    uppyRestrictions = JSON.parse(uppyRestrictions);
  }

  var closest = function(el, fn) {
    return el && (fn(el) ? el : closest(el.parentNode, fn));
  }

  var containerForm = closest(container, function(el) { return el.tagName.toLowerCase() == "form" });
  var cachedFileTableEl = containerForm.querySelector("*[data-cached-files-table]")

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
  if (container.dataset.uploadDirectDestination == 's3') {
    uppy.use(Uppy.AwsS3, {
      serverUrl: '/', // will call Shrine's presign endpoint mounted on `/s3/params`
    })
  } else {
    uppy.use(Uppy.XHRUpload, {
      endpoint: localUploadEndpoint, // Shrine's upload endpoint
      fieldName: 'file',
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
  var makeHiddenFieldForCachedFile = function(file, response) {
    var hidden = document.createElement("input");
    hidden.setAttribute("type", "hidden");
    hidden.setAttribute("name", "cached_files[]");
    hidden.setAttribute("value", JSON.stringify(response));

    return hidden;
  }

  // create a DOM element for a table row that will be the list of succesfully
  // direct uploaded files, including hidden inputs to be submitted with form,
  // and a remove button to remove it from list.
  //
  // With just browser API, yeah, it's a bit ugly code.
  var makeCachedFileRow = function(file, response) {
    var row = document.createElement("tr");

    var firstCell = row.appendChild(document.createElement("td"));
    firstCell.appendChild(makeHiddenFieldForCachedFile(file, response));
    firstCell.appendChild(document.createTextNode(file.name));

    row.appendChild(document.createElement("td")).innerText = fileSizeSI(file.size);
    row.appendChild(document.createElement("td")).innerHTML =
      "<button type='button' data-cached-file-remove='true' class='btn btn-outline-primary'>Remove</button>";

    return row;
  }

  // When a file is fully direct uploaded by uppy, we remove it from uppy dashboard,
  // and instead list it in our list of files to be attached on form submit.
  uppy.on("upload-success", function(file, response) {
    // add the file to our list that will be submitted with form
    cachedFileTableEl.appendChild(makeCachedFileRow(file, response));

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

      var submit = containerForm.querySelector("*[data-uppy-dashboard-submit]");
      if (submit) {
        if (uploadInProgress) {
          submit.setAttribute("disabled", true);
        } else {
          submit.removeAttribute("disabled");
        }
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
  document.querySelectorAll('*[data-create-uppy-dashboard]').forEach(function (container) {
    createUppyDashboard(container);
  })
});
